# syntax=docker/dockerfile:1
#
# Plone 3.1.x — FIRST buildout-era image (Zope 2.10.x / Python 2.4.x)
#
# Strategy:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): Python 2.4 + PIL, then an OFFLINE buildout from the
#                    UnifiedInstaller's bundled buildout-cache
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# [V 2026-08-20] Why this is not a tarball image, despite 3.1 being listed as
# "tarball" in the matrix: there is no full Plone-3.1.x.tar.gz anywhere.
# dist.plone.org carries only PloneBase-3.1.x (the stripped core, without
# dependency products) and its /release/ tree begins at 3.2. The UnifiedInstaller
# is the only complete published source for 3.1.7, and it is buildout-based.
#
# NOT FOR PRODUCTION. Zope 2.10 has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

ARG PYTHON_VERSION=2.4.6
ARG PLONE_VERSION=3.1.7
ARG PIL_VERSION=1.1.6
# Zope is NOT fetched separately here: the installer's buildout-cache ships
# Zope-2.10.6-final.tgz and plone.recipe.zope2install builds it during buildout.
ARG ZOPE_VERSION=2.10.6

ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# [V 2026-08-20] Verified downloadable (34.9 MB gzip). Launchpad is the only
# host serving the 3.1.7 UnifiedInstaller; dist.plone.org has no equivalent.
ARG PLONE_URL=https://launchpad.net/plone/3.1/${PLONE_VERSION}/+download/Plone-${PLONE_VERSION}-UnifiedInstaller.tgz
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
ARG PYTHON_URL
ARG PLONE_URL
ARG PIL_URL
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /dist
RUN curl -fSL "${PYTHON_URL}" -o python.tgz \
 && curl -fSL "${PLONE_URL}"  -o installer.tgz \
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
# Stage 2a: pybuild — Python 2.4 only (gate G1)
# ---------------------------------------------------------------------------
FROM debian:bookworm AS pybuild
ARG PYTHON_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc make libc6-dev zlib1g-dev libcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /dist /dist
COPY shared/build-python2.sh /usr/local/bin/build-python2.sh

RUN build-python2.sh /dist/python.tgz "${PYTHON_VERSION}" /opt/python2.4

# ---------------------------------------------------------------------------
# Stage 2b: build — PIL, then the offline buildout.
# ---------------------------------------------------------------------------
FROM pybuild AS build
ARG PLONE_VERSION
ARG PIL_VERSION

# bzip2: the buildout-cache is a .tar.bz2.
# The rest are Zope 2.10's build deps — plone.recipe.zope2install compiles Zope
# from the cached tarball during buildout, so the toolchain must be present.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev bzip2 \
 && rm -rf /var/lib/apt/lists/*

COPY shared/build-pil.sh /usr/local/bin/build-pil.sh
RUN build-pil.sh /dist/pil.tar.gz "${PIL_VERSION}" /opt/python2.4/bin/python2.4

# ElementTree is NOT installed separately here: the buildout-cache ships an
# elementtree egg and the template's buildout.cfg already lists it under eggs.
COPY shared/build-plone-buildout.sh /usr/local/bin/build-plone-buildout.sh
RUN build-plone-buildout.sh /dist/installer.tgz "${PLONE_VERSION}" \
      /opt/python2.4/bin/python2.4 /app

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
COPY --from=build --chown=plone:plone /app /app
COPY --chown=plone:plone shared/docker-entrypoint-buildout.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY --chown=plone:plone shared/upgrade-plone.py /app/upgrade-plone.py
COPY --chown=plone:plone shared/configure-zeo.sh /app/configure-zeo.sh
RUN chmod +x /app/configure-zeo.sh

ENV INSTANCE_HOME=/app/instance \
    PYTHON=/opt/python2.4/bin/python2.4 \
    ZOPE_HTTP_PORT=8080

VOLUME /data
EXPOSE 8080
WORKDIR /app/instance
USER plone

# Plone 3.1 registers a large ZCML tree at first start; allow a long warm-up.
HEALTHCHECK --interval=10s --timeout=5s --start-period=180s --retries=6 \
  CMD ["/opt/python2.4/bin/python2.4", "-c", "import urllib; urllib.urlopen('http://127.0.0.1:8080/')"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
