# syntax=docker/dockerfile:1
#
# Plone 2.0.x — tarball era (Zope 2.7.x / Python 2.3.x)
#
# The oldest image in the matrix. Strategy:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): compile Python 2.3 + PIL + Zope 2.7 on bookworm (gcc 12: warns, doesn't error)
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# The Python and PIL builds live in shared/build-python2.sh and
# shared/build-pil.sh, which every tarball-era image uses.
#
# NOT FOR PRODUCTION. Zope 2.7 has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

# [V 2026-08-20] Zope 2.7.8's ./configure declares TARGET="2.3.5" and
# ACCEPTABLE="2.3.4 2.3.3", which does NOT list 2.3.7 — but that list is only
# consulted by get_python(), the $PATH search. Passing --with-python=<path>
# sets FOUND directly and skips get_python() entirely, and inst/configure.py
# (the real configurator) gates only on pyexpat, zlib and large-file support,
# never on sys.version. So 2.3.7 is accepted. It is preferred over the
# declared 2.3.5 target because it is the last 2.3.x (2008) and carries four
# more years of fixes toward building on a modern toolchain; 2.3.x is stable
# within the series, so Zope's C extensions are unaffected.
# [V 2026-08-20] 2.3.7 bundles expat (Modules/expat/) and defines
# HAVE_LARGEFILE_SUPPORT, so both of Zope's hard gates are satisfiable.
ARG PYTHON_VERSION=2.3.7
ARG ZOPE_VERSION=2.7.8
ARG PLONE_VERSION=2.0.5
# [V 2026-08-20] Unlike 2.1.4 and 2.5.4, Plone 2.0.5 does NOT require PIL:
# CMFPlone never imports it, and the single use site guards itself —
#   Archetypes/Field.py:964  try: import PIL.Image / except: has_pil=None
# It is bundled anyway (Érico's call, 2026-08-20) so image scaling actually
# works rather than silently degrading during a migration rehearsal, and so
# all three tarball-era images have the same shape.
ARG PIL_VERSION=1.1.6

# [V 2026-08-20] Verified: Zope-2.7.8-final.tgz (2.9 MB) exists at old.zope.dev
# and unpacks to Zope-2.7.8-final/ with a top-level ./configure.
ARG ZOPE_URL=https://old.zope.dev/Products/Zope/${ZOPE_VERSION}/Zope-${ZOPE_VERSION}-final.tgz
# [V] python.org keeps all historical releases
ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# [V 2026-08-20] Verified: Plone-2.0.5.tar.gz (4.2 MB, 2004-12-01) exists at
# dist.plone.org/archive/ and is the last 2.0.x (only RCs follow it).
ARG PLONE_URL=https://dist.plone.org/archive/Plone-${PLONE_VERSION}.tar.gz
# [V 2026-08-20] effbot.org is dead (404) and PyPI lists PIL but serves no
# files; dist.plone.org/thirdparty is the surviving canonical source.
ARG PIL_URL=https://dist.plone.org/thirdparty/PIL-${PIL_VERSION}.tar.gz

# --- simplejson -------------------------------------------------------------
# Python has no stdlib `json` before 2.6, so every image below 4.0 ships
# simplejson instead. The release is NOT interchangeable between interpreters
# — see the header of shared/install-simplejson.sh, and note that the install
# gate will fail the build on a wrong pairing rather than let it through.
ARG SIMPLEJSON_VERSION=1.9.3
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
# Stage 2a: pybuild — Python 2.3 only, so `--target pybuild` is exactly gate G1
# and a Zope failure cannot deny us a testable interpreter.
# ---------------------------------------------------------------------------
FROM debian:bookworm AS pybuild
ARG PYTHON_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc make libc6-dev zlib1g-dev libcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /dist /dist
COPY shared/build-python2.sh /usr/local/bin/build-python2.sh

RUN build-python2.sh /dist/python.tgz "${PYTHON_VERSION}" /opt/python2.3

# ---------------------------------------------------------------------------
# Stage 2b: build — PIL, Zope 2.7, the Zope instance, and the Plone products.
# ---------------------------------------------------------------------------
FROM pybuild AS build
ARG ZOPE_VERSION
ARG PLONE_VERSION
ARG PIL_VERSION

# --- PIL --------------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev \
 && rm -rf /var/lib/apt/lists/*

COPY shared/build-pil.sh /usr/local/bin/build-pil.sh
RUN build-pil.sh /dist/pil.tar.gz "${PIL_VERSION}" /opt/python2.3/bin/python2.3

# --- Zope 2.7 ---------------------------------------------------------------
# Oldest C in the matrix: this is the pre-rewrite ExtensionClass. -fcommon
# avoids gcc>=10 "multiple definition" errors from tentative definitions.
RUN tar -xzf /dist/zope.tgz -C /tmp \
 && cd /tmp/Zope-${ZOPE_VERSION}-final \
 && ./configure --prefix=/opt/zope \
      --with-python=/opt/python2.3/bin/python2.3 \
 && CFLAGS="-fcommon -fno-strict-aliasing" make \
 && make install \
 && rm -rf /tmp/Zope-${ZOPE_VERSION}-final

# --- Zope instance + Plone products -----------------------------------------
# Placeholder inituser; the real one is written by the entrypoint at runtime.
RUN /opt/python2.3/bin/python2.3 /opt/zope/bin/mkzopeinstance.py \
      --dir /app/instance --user "admin:placeholder"

# [V 2026-08-20] Bundle layout is Plone-2.0.5/<ProductName>/..., 20 product
# directories, confirmed with `tar -tzf` — same shape as 2.1.4 and 2.5.4-2,
# so --strip-components=1 is correct.
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
# site-packages lives under /opt/python2.3, which stage 3 copies wholesale, so
# nothing further is needed at runtime.
ARG SIMPLEJSON_VERSION
COPY --from=fetch-simplejson /dist/simplejson.tar.gz /dist/simplejson.tar.gz
COPY shared/install-simplejson.sh /usr/local/bin/install-simplejson.sh
RUN install-simplejson.sh /dist/simplejson.tar.gz "${SIMPLEJSON_VERSION}" \
      /opt/python2.3/bin/python2.3

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

COPY --from=build --chown=plone:plone /opt/python2.3 /opt/python2.3
COPY --from=build --chown=plone:plone /opt/zope /opt/zope
COPY --from=build --chown=plone:plone /app /app
COPY --chown=plone:plone shared/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY --chown=plone:plone shared/upgrade-plone.py /app/upgrade-plone.py
COPY --chown=plone:plone shared/configure-zeo.sh /app/configure-zeo.sh
RUN chmod +x /app/configure-zeo.sh

ENV ZOPE_HOME=/opt/zope \
    INSTANCE_HOME=/app/instance \
    PYTHON=/opt/python2.3/bin/python2.3 \
    ZOPE_HTTP_PORT=8080

VOLUME /data
EXPOSE 8080
WORKDIR /app
USER plone

# ZServer is slow to warm up on first start (Data.fs creation + product init)
HEALTHCHECK --interval=10s --timeout=5s --start-period=120s --retries=5 \
  CMD ["/opt/python2.3/bin/python2.3", "-c", "import urllib; urllib.urlopen('http://127.0.0.1:8080/')"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
