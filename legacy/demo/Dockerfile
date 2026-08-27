# syntax=docker/dockerfile:1
#
# The -demo variant of any image in the matrix.
#
# One Dockerfile serves all eleven versions: it takes the already-built base
# image as a build argument and adds a database with a Plone site already in
# it, at the id `Plone`. Nothing else differs — same Zope, same Python, same
# products, same entrypoint.
#
#   docker build -f demo/Dockerfile --build-arg BASE_IMAGE=plone-legacy:2.1.4 \
#       -t plone-legacy:2.1.4-demo .
#
# or just `make demo-2.1`, which builds the base first.
#
# NOT FOR PRODUCTION — and rather more so than the base images: the admin
# password is baked in at build time and is `admin` unless you override it.
ARG BASE_IMAGE

# ---------------------------------------------------------------------------
# Stage 1: seed — start the instance, create the site, keep the Data.fs
# ---------------------------------------------------------------------------
# This stage is thrown away. It exists so that curl (needed to drive the ZMI,
# and absent from the slim runtime) never reaches the published demo image.
FROM ${BASE_IMAGE} AS seed

ARG DEMO_SITE_ID=Plone
ARG DEMO_SITE_TITLE="Plone demo"
ARG DEMO_ADMIN_USER=admin
# [Decision 2026-08-20] Baked at build time, because the site — and therefore
# the admin user inside it — is created here. A runtime ADMIN_PASSWORD cannot
# apply to a database that already has its users; the entrypoint says so out
# loud rather than appearing to accept it. Override with --build-arg.
#
# hadolint's DL3064 is right in general and is suppressed knowingly: the point
# of a demo image is that its credentials are known, and the resulting database
# — which is the actual secret-bearing artifact — is baked in regardless. These
# images are never for production; do not expose one.
# hadolint ignore=DL3064
ARG DEMO_ADMIN_PASSWORD=admin

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

COPY shared/create-plone-site.sh /usr/local/bin/create-plone-site.sh
COPY shared/seed-demo-site.sh /usr/local/bin/seed-demo-site.sh
RUN chmod +x /usr/local/bin/create-plone-site.sh /usr/local/bin/seed-demo-site.sh

# Back to the runtime user: the database is written by the same uid that will
# own it later, through the image's own entrypoint.
USER plone
# hadolint ignore=DL3064
ENV SITE_ID=${DEMO_SITE_ID} \
    SITE_TITLE=${DEMO_SITE_TITLE} \
    ADMIN_USER=${DEMO_ADMIN_USER} \
    ADMIN_PASSWORD=${DEMO_ADMIN_PASSWORD}
RUN seed-demo-site.sh

# ---------------------------------------------------------------------------
# Stage 2: the demo image — the base, plus the seeded database
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG DEMO_SITE_ID=Plone
ARG DEMO_ADMIN_USER=admin

LABEL org.opencontainers.image.description="Demo variant of ${BASE_IMAGE}: identical, but ships a database with a Plone site already created at /${DEMO_SITE_ID}. Migration, demonstration and archaeology only — NOT for production."

# The only difference from the base image. The entrypoint copies it into
# /data/filestorage/ on first start, and does nothing if /data already has a
# database — so mounting a real site over it still works.
COPY --from=seed --chown=plone:plone /app/seed /app/seed

# Ships alongside the database, and only here: the entrypoint runs it right
# after seeding, so that ADMIN_PASSWORD applies to a pre-created site the same
# way it applies to a fresh one. Base images have neither file, and the
# entrypoint's seeding branch is a no-op for them.
COPY --chown=plone:plone shared/reset-admin-password.py /app/seed/reset-admin-password.py

ENV DEMO_SITE_ID=${DEMO_SITE_ID} \
    DEMO_ADMIN_USER=${DEMO_ADMIN_USER}
