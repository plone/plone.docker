# syntax=docker/dockerfile:1
#
# Plone 2.1.x — tarball era (Zope 2.8.x / Python 2.4.x)
#
# Strategy:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): compile Python 2.4 + PIL + Zope 2.8 on bookworm (gcc 12: warns, doesn't error)
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# The Python and PIL builds live in shared/build-python2.sh and
# shared/build-pil.sh, which every tarball-era image uses. Their inline
# comments carry the reasoning for each mitigation.
#
# NOT FOR PRODUCTION. Zope 2.8 has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

ARG PYTHON_VERSION=2.4.6
ARG ZOPE_VERSION=2.8.12
ARG PLONE_VERSION=2.1.4
# [V 2026-08-20] CMFPlone 2.1.4 imports PIL unconditionally, so this is a hard
# requirement, not an image-scaling nicety. 1.1.6 is contemporary with Plone
# 2.1.4 (both 2006) and is the version named by decision D4.
ARG PIL_VERSION=1.1.6

# [V] Verified 2026-08-19: Zope-2.8.12-final.tgz exists at old.zope.dev
ARG ZOPE_URL=https://old.zope.dev/Products/Zope/${ZOPE_VERSION}/Zope-${ZOPE_VERSION}-final.tgz
# [V] python.org keeps all historical releases
ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# [V] Verified 2026-08-19: Plone-2.1.4.tar.gz exists at dist.plone.org/archive/
#     (the archive covers the whole tarball era: 2.0.x, 2.1.x, 2.5.x, 3.0.x)
ARG PLONE_URL=https://dist.plone.org/archive/Plone-${PLONE_VERSION}.tar.gz
# [V 2026-08-20] effbot.org is dead (404) and PyPI lists PIL but serves no
# files; dist.plone.org/thirdparty is the surviving canonical source. Note this
# is the Plone-community repackaging of PIL, not the stock effbot tarball.
ARG PIL_URL=https://dist.plone.org/thirdparty/PIL-${PIL_VERSION}.tar.gz

# --- simplejson -------------------------------------------------------------
# Python has no stdlib `json` before 2.6, so every image below 4.0 ships
# simplejson instead. The release is NOT interchangeable between interpreters
# — see the header of shared/install-simplejson.sh, and note that the install
# gate will fail the build on a wrong pairing rather than let it through.
ARG SIMPLEJSON_VERSION=2.0.9
ARG SIMPLEJSON_URL=https://files.pythonhosted.org/packages/source/s/simplejson/simplejson-${SIMPLEJSON_VERSION}.tar.gz

# ---------------------------------------------------------------------------
# Stage 1: fetch — modern TLS, nothing else
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS fetch
ARG ZOPE_URL
ARG PYTHON_URL
ARG PLONE_URL
ARG PIL_URL
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /dist
RUN curl -fSL "${PYTHON_URL}" -o python.tgz \
 && curl -fSL "${ZOPE_URL}"   -o zope.tgz \
 && curl -fSL "${PLONE_URL}"  -o plone.tar.gz \
 && curl -fSL "${PIL_URL}"    -o pil.tar.gz

# ---------------------------------------------------------------------------
# Stage 1b: fetch-simplejson — derived from fetch, deliberately not part of it
# ---------------------------------------------------------------------------
# pybuild does `COPY --from=fetch /dist /dist`, so folding this download into
# stage 1 would invalidate the interpreter build every time the simplejson pin
# moves and recompile CPython from source — hours, under emulation on an arm64
# host. Deriving a stage leaves `fetch` byte-identical, so pybuild stays cached,
# and reuses the curl and ca-certificates already installed there. WORKDIR
# /dist is inherited, so the tarball lands beside the others.
FROM fetch AS fetch-simplejson
ARG SIMPLEJSON_URL
RUN curl -fSL --retry 5 --retry-delay 5 "${SIMPLEJSON_URL}" -o simplejson.tar.gz

# ---------------------------------------------------------------------------
# Stage 2a: pybuild — Python 2.4 only.
# Split from the Zope stage so that `--target pybuild` is exactly gate G1:
# a failure in Zope (G2) must not deny us a testable Python artifact.
# ---------------------------------------------------------------------------
FROM debian:bookworm AS pybuild
ARG PYTHON_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc make libc6-dev zlib1g-dev libcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /dist /dist
COPY shared/build-python2.sh /usr/local/bin/build-python2.sh

# Gate G1: the script asserts `import zlib, sha, md5, crypt, socket, ...`.
RUN build-python2.sh /dist/python.tgz "${PYTHON_VERSION}" /opt/python2.4

# ---------------------------------------------------------------------------
# Stage 2b: build — PIL, Zope 2.8, the Zope instance, and the Plone products.
# ---------------------------------------------------------------------------
FROM pybuild AS build
ARG ZOPE_VERSION
ARG PLONE_VERSION
ARG PIL_VERSION

# --- PIL --------------------------------------------------------------------
# [V 2026-08-20] Required for Plone to load at all: CMFPlone/utils.py line 4 is
# an unconditional `from PIL import Image`, and without it CMFPlone, Archetypes
# and ATContentTypes all fail to import (decisions D2/D4).
RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev \
 && rm -rf /var/lib/apt/lists/*

COPY shared/build-pil.sh /usr/local/bin/build-pil.sh
RUN build-pil.sh /dist/pil.tar.gz "${PIL_VERSION}" /opt/python2.4/bin/python2.4

# --- Zope 2.8 ---------------------------------------------------------------
# Zope 2.8 uses configure + make (distutils underneath). -fcommon avoids
# gcc>=10 "multiple definition" errors from tentative definitions in the
# old C extensions (ExtensionClass, cAccessControl, ZODB).
RUN tar -xzf /dist/zope.tgz -C /tmp \
 && cd /tmp/Zope-${ZOPE_VERSION}-final \
 && ./configure --prefix=/opt/zope \
      --with-python=/opt/python2.4/bin/python2.4 \
 && CFLAGS="-fcommon -fno-strict-aliasing" make \
 && make install \
 && rm -rf /tmp/Zope-${ZOPE_VERSION}-final

# --- Zope instance + Plone products -----------------------------------------
# Placeholder inituser; the real one is written by the entrypoint at runtime.
RUN /opt/python2.4/bin/python2.4 /opt/zope/bin/mkzopeinstance.py \
      --dir /app/instance --user "admin:placeholder"

# [V 2026-08-20] Bundle layout is Plone-2.1.4/<ProductName>/... (one dir per
# product: CMFPlone, Archetypes, ATContentTypes, CMFQuickInstallerTool, ...),
# confirmed with `tar -tzf`, so --strip-components=1 is correct.
# Gate: `ls /app/instance/Products/CMFPlone/version.txt` succeeds.
RUN mkdir -p /tmp/plone \
 && tar -xzf /dist/plone.tar.gz -C /tmp/plone --strip-components=1 \
 && cp -a /tmp/plone/. /app/instance/Products/ \
 && test -d /app/instance/Products/CMFPlone \
 && rm -rf /tmp/plone

# Point the filestorage and logs at /data (populated at runtime).
RUN sed -i \
      -e 's|\$INSTANCE/var/Data.fs|/data/filestorage/Data.fs|' \
      -e 's|\$INSTANCE/log|/data/log|' \
      /app/instance/etc/zope.conf

# --- simplejson -------------------------------------------------------------
# Last in the stage, and with its ARG declared here rather than at the top, so
# that moving the pin does not invalidate the PIL and Plone layers above.
# site-packages lives under /opt/python2.4, which stage 3 copies wholesale, so
# nothing further is needed at runtime.
ARG SIMPLEJSON_VERSION
COPY --from=fetch-simplejson /dist/simplejson.tar.gz /dist/simplejson.tar.gz
COPY shared/install-simplejson.sh /usr/local/bin/install-simplejson.sh
RUN install-simplejson.sh /dist/simplejson.tar.gz "${SIMPLEJSON_VERSION}" \
      /opt/python2.4/bin/python2.4

# ---------------------------------------------------------------------------
# Stage 3: runtime
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim
ARG PLONE_VERSION
ARG ZOPE_VERSION
ARG PYTHON_VERSION

LABEL org.opencontainers.image.title="Plone ${PLONE_VERSION} (legacy)" \
      org.opencontainers.image.description="Plone ${PLONE_VERSION} on Zope ${ZOPE_VERSION} / Python ${PYTHON_VERSION}. Migration and content-extraction use only — NOT for production." \
      org.opencontainers.image.vendor="Simples Consultoria"

RUN apt-get update \
 && apt-get install -y --no-install-recommends zlib1g libcrypt1 libjpeg62-turbo \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system -m -d /app -U -u 500 plone \
 && mkdir -p /data \
 && chown -R plone:plone /data

COPY --from=build --chown=plone:plone /opt/python2.4 /opt/python2.4
COPY --from=build --chown=plone:plone /opt/zope /opt/zope
COPY --from=build --chown=plone:plone /app /app
COPY --chown=plone:plone shared/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY --chown=plone:plone shared/upgrade-plone.py /app/upgrade-plone.py
COPY --chown=plone:plone shared/configure-zeo.sh /app/configure-zeo.sh
RUN chmod +x /app/configure-zeo.sh

ENV ZOPE_HOME=/opt/zope \
    INSTANCE_HOME=/app/instance \
    PYTHON=/opt/python2.4/bin/python2.4 \
    ZOPE_HTTP_PORT=8080

VOLUME /data
EXPOSE 8080
WORKDIR /app
USER plone

# ZServer is slow to warm up on first start (Data.fs creation + product init)
HEALTHCHECK --interval=10s --timeout=5s --start-period=120s --retries=5 \
  CMD ["/opt/python2.4/bin/python2.4", "-c", "import urllib; urllib.urlopen('http://127.0.0.1:8080/')"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
