# syntax=docker/dockerfile:1
#
# Plone 4.0.x — buildout era (Zope 2.12.19 / Python 2.6.9)
#
# Strategy:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): Python 2.6 + PIL, then an OFFLINE buildout from the
#                    UnifiedInstaller's bundled buildout-cache
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# [V 2026-08-20] 4.0.9, NOT 4.0.10. 4.0.10 is the final 4.0.x release and its
# egg set exists at dist.plone.org/release/4.0.10/, but Launchpad has no
# UnifiedInstaller past 4.0.9 — and the installer is what carries the offline
# buildout-cache these images depend on.
#
# [V 2026-08-20] Plone 4 packages Zope as an EGG (Zope2-2.12.19), not the
# configure+make tarball used through 3.x. The buildout handles that itself,
# which is the main reason these images are built from the UnifiedInstaller
# rather than assembled by hand.
#
# NOT FOR PRODUCTION. This stack has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

ARG PYTHON_VERSION=2.6.9
ARG PLONE_VERSION=4.0.9
ARG PIL_VERSION=1.1.6
ARG ZOPE_VERSION=2.12.19

ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
ARG PLONE_URL=https://launchpad.net/plone/4.0/${PLONE_VERSION}/+download/Plone-${PLONE_VERSION}-UnifiedInstaller.tgz
ARG PIL_URL=https://dist.plone.org/thirdparty/PIL-${PIL_VERSION}.tar.gz

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
# --retry: Launchpad intermittently answers 503 under load (observed repeatedly
# on 2026-08-20), and a transient failure here wastes the whole build.
RUN curl -fSL --retry 5 --retry-delay 5 "${PYTHON_URL}" -o python.tgz \
 && curl -fSL --retry 5 --retry-delay 5 "${PLONE_URL}"  -o installer.tgz \
 && curl -fSL --retry 5 --retry-delay 5 "${PIL_URL}"    -o pil.tar.gz

# ---------------------------------------------------------------------------
# Stage 2a: pybuild — the interpreter only (gate G1)
# ---------------------------------------------------------------------------
FROM debian:bookworm AS pybuild
ARG PYTHON_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gcc make libc6-dev zlib1g-dev libcrypt-dev \
 && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /dist /dist
COPY shared/build-python2.sh /usr/local/bin/build-python2.sh

RUN build-python2.sh /dist/python.tgz "${PYTHON_VERSION}" /opt/python2.6

# ---------------------------------------------------------------------------
# Stage 2b: build — PIL, then the offline buildout.
# ---------------------------------------------------------------------------
FROM pybuild AS build
ARG PLONE_VERSION
ARG PIL_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev bzip2 \
 && rm -rf /var/lib/apt/lists/*

COPY shared/build-pil.sh /usr/local/bin/build-pil.sh
RUN build-pil.sh /dist/pil.tar.gz "${PIL_VERSION}" /opt/python2.6/bin/python2.6

COPY shared/build-plone-buildout.sh /usr/local/bin/build-plone-buildout.sh
RUN build-plone-buildout.sh /dist/installer.tgz "${PLONE_VERSION}" \
      /opt/python2.6/bin/python2.6 /app

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

COPY --from=build --chown=plone:plone /opt/python2.6 /opt/python2.6
COPY --from=build --chown=plone:plone /app /app
COPY --chown=plone:plone shared/docker-entrypoint-buildout.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
COPY --chown=plone:plone shared/upgrade-plone.py /app/upgrade-plone.py
COPY --chown=plone:plone shared/configure-zeo.sh /app/configure-zeo.sh
RUN chmod +x /app/configure-zeo.sh

ENV INSTANCE_HOME=/app/instance \
    PYTHON=/opt/python2.6/bin/python2.6 \
    ZOPE_HTTP_PORT=8080

VOLUME /data
EXPOSE 8080
WORKDIR /app/instance
USER plone

HEALTHCHECK --interval=10s --timeout=5s --start-period=180s --retries=6 \
  CMD ["/opt/python2.6/bin/python2.6", "-c", "import urllib; urllib.urlopen('http://127.0.0.1:8080/')"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
