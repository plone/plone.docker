# syntax=docker/dockerfile:1
#
# Plone 1.0.x — tarball era (Zope 2.7.x / Python 2.3.x)
#
# The oldest Plone in the matrix, and the only image that patches upstream
# source. Strategy is otherwise identical to 2.0:
#   Stage 1 (fetch): modern userland downloads everything (old TLS never touches network)
#   Stage 2 (build): compile Python 2.3 + PIL + Zope 2.7 on bookworm (gcc 12: warns, doesn't error)
#   Stage 3 (runtime): slim image, non-root, /data volume, port 8080
#
# NOT FOR PRODUCTION. Zope 2.7 has known, unpatched security issues.
# Intended for content extraction, migration, and archaeology only.

# [V 2026-08-20] Plone 1.0.6 targets Zope 2.6.x, whose CMFPlone/INSTALL.txt
# asks for "Zope 2.5.1 or later" and "CMF 1.3 or later". Zope 2.6.4 requires
# Python 2.1 and uses a different build system entirely (wo_pcgi.py, and
# inst/make_instance.py rather than mkzopeinstance.py), so it would have meant
# a new interpreter and a new template. It is not needed: Plone 1.0.6 runs on
# Zope 2.7.8 / Python 2.3.7 — the exact stack 2.0 already ships — once two
# upstream files are ported. See patches/ and README.md.
ARG PYTHON_VERSION=2.3.7
ARG ZOPE_VERSION=2.7.8
ARG PLONE_VERSION=1.0.6
# [V 2026-08-20] The 1.0.5 bundle is the source of DCWorkflow and Formulator;
# see PLONE_BUNDLE_URL below.
ARG PLONE_BUNDLE_VERSION=1.0.5
# [V 2026-08-20] Last of the CMF 1.3 line, which is what 1.0.6 asks for. CMF
# 1.4 is a Zope 2.7-era API and predates nothing Plone 1.0 knows about.
ARG CMF_VERSION=1.3.3
# [V 2026-08-20] Plone 1.0.6 never imports PIL — unlike 2.1.4 and 2.5.4, and
# like 2.0.5, whose only use site is guarded. Bundled anyway for the same
# reason as 2.0: image scaling works rather than silently degrading during a
# migration rehearsal, and every tarball-era image keeps the same shape.
ARG PIL_VERSION=1.1.6

# [V 2026-08-20] Verified: Zope-2.7.8-final.tgz (2.9 MB) exists at old.zope.dev
# and unpacks to Zope-2.7.8-final/ with a top-level ./configure.
ARG ZOPE_URL=https://old.zope.dev/Products/Zope/${ZOPE_VERSION}/Zope-${ZOPE_VERSION}-final.tgz
# [V] python.org keeps all historical releases
ARG PYTHON_URL=https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
# [V 2026-08-20] Plone-1.0.6.tar.gz (406 KB) exists at dist.plone.org/archive/
# and unpacks to a bare CMFPlone/ — it is the CMFPlone product ALONE, not a
# bundle like every 2.x tarball. Note also that Plone-1.0.tar.gz, -1.0.1 and
# -1.0.2 are listed in that index but all 404, serving a 3 kB HTML error page.
ARG PLONE_URL=https://dist.plone.org/archive/Plone-${PLONE_VERSION}.tar.gz
# [V 2026-08-20] CMFPlone1.0.5.tar.gz (1.4 MB) is the real 1.0 release bundle:
# CMFPlone-1.0.5/{CMFPlone,DCWorkflow,Formulator,i18n}. INSTALL.txt names
# exactly those three products, and DCWorkflow 0.5+ / Formulator 1.4.1 are not
# separately downloadable anywhere — old.zope.dev 404s both. So 1.0.6 supplies
# CMFPlone and the 1.0.5 bundle supplies its two companions.
ARG PLONE_BUNDLE_URL=https://dist.plone.org/archive/CMFPlone${PLONE_BUNDLE_VERSION}.tar.gz
# [V 2026-08-20] Verified: CMF-1.3.3.tar.gz unpacks to CMF-1.3.3/ carrying
# CMFCore, CMFDefault, CMFTopic and CMFCalendar.
ARG CMF_URL=https://old.zope.dev/Products/CMF/CMF-${CMF_VERSION}/CMF-${CMF_VERSION}.tar.gz
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
ARG PLONE_BUNDLE_URL
ARG CMF_URL
ARG PIL_URL
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /dist
RUN curl -fSL "${PYTHON_URL}"       -o python.tgz \
 && curl -fSL "${ZOPE_URL}"         -o zope.tgz \
 && curl -fSL "${PLONE_URL}"        -o plone.tar.gz \
 && curl -fSL "${PLONE_BUNDLE_URL}" -o plone-bundle.tar.gz \
 && curl -fSL "${CMF_URL}"          -o cmf.tar.gz \
 && curl -fSL "${PIL_URL}"          -o pil.tar.gz

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
ARG PLONE_BUNDLE_VERSION
ARG CMF_VERSION
ARG PIL_VERSION

# --- PIL --------------------------------------------------------------------
# `patch` is needed here and nowhere else in the matrix: see the port step below.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libjpeg62-turbo-dev patch \
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

# --- Zope instance ----------------------------------------------------------
# Placeholder inituser; the real one is written by the entrypoint at runtime.
RUN /opt/python2.3/bin/python2.3 /opt/zope/bin/mkzopeinstance.py \
      --dir /app/instance --user "admin:placeholder"

# --- Plone products ---------------------------------------------------------
# Three sources, because no single 1.0.6 artifact carries the whole set:
#   Plone-1.0.6.tar.gz     -> CMFPlone                      (bare, no prefix)
#   CMFPlone1.0.5.tar.gz   -> DCWorkflow, Formulator        (strip 1)
#   CMF-1.3.3.tar.gz       -> CMFCore, CMFDefault, CMFTopic, CMFCalendar
#
# [V 2026-08-20] CMFPlone's only other imports are Products.Localizer and
# Products.CMFEventService, and BOTH sit behind try/except (PloneInitialize.py:8
# and WorkflowTool.py:15), so neither is required. Everything else it imports —
# ExternalMethod, SiteAccess, PageTemplates, PythonScripts — ships with Zope.
RUN mkdir -p /tmp/plone /tmp/bundle /tmp/cmf \
 && tar -xzf /dist/plone.tar.gz        -C /tmp/plone \
 && tar -xzf /dist/plone-bundle.tar.gz -C /tmp/bundle --strip-components=1 \
 && tar -xzf /dist/cmf.tar.gz          -C /tmp/cmf    --strip-components=1 \
 && cp -a /tmp/plone/CMFPlone                            /app/instance/Products/ \
 && cp -a /tmp/bundle/DCWorkflow /tmp/bundle/Formulator  /app/instance/Products/ \
 && cp -a /tmp/cmf/CMFCore /tmp/cmf/CMFDefault \
          /tmp/cmf/CMFTopic /tmp/cmf/CMFCalendar         /app/instance/Products/ \
 && test "$(cat /app/instance/Products/CMFPlone/version.txt)" = "${PLONE_VERSION}" \
 && test -d /app/instance/Products/CMFCore \
 && test -d /app/instance/Products/DCWorkflow \
 && test -d /app/instance/Products/Formulator \
 && rm -rf /tmp/plone /tmp/bundle /tmp/cmf

# --- Port to Zope 2.7 -------------------------------------------------------
# The ONLY image in this matrix that modifies upstream source. Both patches are
# consequences of running a Zope 2.6-era Plone on Zope 2.7; each is documented
# in README.md with the exact error it fixes. --forward makes a patch that has
# already applied a hard failure rather than a silent re-application, and the
# build stops if either is rejected.
COPY 1.0/patches /tmp/patches
RUN for p in /tmp/patches/*.patch; do \
        echo "applying $(basename "$p")"; \
        patch -p1 --forward --batch -d /app/instance/Products < "$p"; \
    done \
 && rm -rf /tmp/patches

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
      org.opencontainers.image.description="Plone ${PLONE_VERSION} on Zope ${ZOPE_VERSION} / Python ${PYTHON_VERSION}, with two source patches for Zope 2.7. Migration and content-extraction use only — NOT for production." \
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
