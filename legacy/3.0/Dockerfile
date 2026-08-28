# syntax=docker/dockerfile:1
#
# Plone 3.0.x — the LAST tarball-era release (Zope 2.10.x / Python 2.4.x)
#
# Strategy:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): Python 2.4 + PIL + ElementTree + Zope 2.10 on bookworm
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# Two things differ from 2.0/2.1/2.5, both verified rather than assumed:
#   * the bundle is Plone-3.0.5/{Products,lib/python}, not one dir per product,
#     so lib/python must ALSO be installed (see the install step below);
#   * ElementTree is a new hard dependency (see shared/build-elementtree.sh).
#
# NOT FOR PRODUCTION. Zope 2.10 has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

ARG PYTHON_VERSION=2.4.6
ARG ZOPE_VERSION=2.10.13
# [V 2026-08-20] 3.0.5 is the last FULL bundle, not 3.0.6. dist.plone.org has
# PloneBase-3.0.6.tar.gz but no Plone-3.0.6.tar.gz: the 3.0.6 roll shipped only
# as PloneBase, which is the stripped core (CMFPlone alone, 1.0 MB) WITHOUT the
# dependency products. The last full Plone-*.tar.gz for the 3.0 series is
# 3.0.5 (12.6 MB, 41 products), and the repo convention is to always use the
# full bundle. /archive/ holds only UnifiedInstaller tarballs for 3.0.x; the
# plain bundles live at the dist.plone.org root.
ARG PLONE_VERSION=3.0.5
ARG PIL_VERSION=1.1.6
ARG ELEMENTTREE_VERSION=1.2.7-20070827-preview

# [V 2026-08-20] Verified: Zope-2.10.13-final.tgz (7.4 MB) exists at
# old.zope.dev, unpacks to Zope-2.10.13-final/ with a top-level ./configure,
# and its configure declares TARGET="2.4.6" — exactly the interpreter these
# images already build. Plone 3.0's INSTALL.txt requires Zope 2.10.4+.
ARG ZOPE_URL=https://old.zope.dev/Products/Zope/${ZOPE_VERSION}/Zope-${ZOPE_VERSION}-final.tgz
# [V] python.org keeps all historical releases
ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# [V 2026-08-20] Verified: Plone-3.0.5.tar.gz at the dist.plone.org root
# (NOT under /archive/, unlike the 2.x bundles).
ARG PLONE_URL=https://dist.plone.org/Plone-${PLONE_VERSION}.tar.gz
# [V 2026-08-20] effbot.org is dead (404) and PyPI lists PIL but serves no
# files; dist.plone.org/thirdparty is the surviving canonical source.
ARG PIL_URL=https://dist.plone.org/thirdparty/PIL-${PIL_VERSION}.tar.gz
# [V 2026-08-20] Plone's own docs point at effbot.org for this, which is dead.
# The same thirdparty mirror carries it — as a .zip, hence unzip below.
ARG ELEMENTTREE_URL=https://dist.plone.org/thirdparty/elementtree-${ELEMENTTREE_VERSION}.zip

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
ARG ELEMENTTREE_URL
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /dist
RUN curl -fSL "${PYTHON_URL}"      -o python.tgz \
 && curl -fSL "${ZOPE_URL}"        -o zope.tgz \
 && curl -fSL "${PLONE_URL}"       -o plone.tar.gz \
 && curl -fSL "${PIL_URL}"         -o pil.tar.gz \
 && curl -fSL "${ELEMENTTREE_URL}" -o elementtree.zip

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
# Stage 2a: pybuild — Python 2.4 only, so `--target pybuild` is exactly gate G1
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

RUN build-python2.sh /dist/python.tgz "${PYTHON_VERSION}" /opt/python2.4

# ---------------------------------------------------------------------------
# Stage 2b: build — PIL, ElementTree, Zope 2.10, the instance, and Plone.
# ---------------------------------------------------------------------------
FROM pybuild AS build
ARG ZOPE_VERSION
ARG PLONE_VERSION
ARG PIL_VERSION
ARG ELEMENTTREE_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev unzip \
 && rm -rf /var/lib/apt/lists/*

# --- PIL --------------------------------------------------------------------
COPY shared/build-pil.sh /usr/local/bin/build-pil.sh
RUN build-pil.sh /dist/pil.tar.gz "${PIL_VERSION}" /opt/python2.4/bin/python2.4

# --- ElementTree ------------------------------------------------------------
COPY shared/build-elementtree.sh /usr/local/bin/build-elementtree.sh
RUN build-elementtree.sh /dist/elementtree.zip "${ELEMENTTREE_VERSION}" \
      /opt/python2.4/bin/python2.4

# --- Zope 2.10 --------------------------------------------------------------
# Same configure + make as 2.7/2.8/2.9. -fcommon avoids gcc>=10 "multiple
# definition" errors from tentative definitions in the old C extensions.
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

# [V 2026-08-20] The 3.0 bundle layout differs from every 2.x bundle:
#
#     Plone-3.0.5/
#       Products/<41 product dirs>
#       lib/python/{archetypes,five,kss,plone,wicked}
#       INSTALL.txt README.txt RELEASENOTES.txt
#
# so Products/ and lib/python/ must be installed to their counterparts in the
# instance, per INSTALL.txt: "The Zope Products are installed in the usual
# location: the Products directory of the Zope instance. Python package may be
# installed in the lib/python directory in the Zope instance".
#
# [V 2026-08-20] <instance>/lib/python IS on sys.path: Zope 2.10's
# Zope2/Startup/handlers.py:187 says "always insert instancehome/lib/python",
# and mkzopeinstance creates that directory in the skeleton.
#
# Both copies are asserted, so a layout change in a future bundle fails the
# build instead of yielding an instance that starts with half of Plone missing.
RUN mkdir -p /tmp/plone \
 && tar -xzf /dist/plone.tar.gz -C /tmp/plone --strip-components=1 \
 && test -d /tmp/plone/Products \
 && test -d /tmp/plone/lib/python \
 && cp -a /tmp/plone/Products/. /app/instance/Products/ \
 && cp -a /tmp/plone/lib/python/. /app/instance/lib/python/ \
 && test -f /app/instance/Products/CMFPlone/version.txt \
 && test -d /app/instance/lib/python/plone \
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

# Plone 3 does considerably more work at first start than 2.x (Five/ZCML
# registration across 41 products), so the warm-up window is longer.
HEALTHCHECK --interval=10s --timeout=5s --start-period=180s --retries=6 \
  CMD ["/opt/python2.4/bin/python2.4", "-c", "import urllib; urllib.urlopen('http://127.0.0.1:8080/')"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
