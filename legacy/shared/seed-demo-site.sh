#!/bin/sh
# Build-time step behind the -demo images: start the instance, create a Plone
# site, shut down cleanly, and bake the resulting database at /app/seed/Data.fs.
#
# Runs INSIDE the image being built, as the `plone` user, through the image's
# own entrypoint — so the database is produced by exactly the same startup path
# that will later open it, rather than by a special build-only configuration.
#
# The seed deliberately lands at /app/seed and NOT at /data: /data is a VOLUME
# in the base image, and anything a layer writes underneath a volume mount point
# is discarded when that layer is committed. The entrypoint copies it into
# place on first start instead.
set -eu

SITE_ID="${SITE_ID:-Plone}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
PORT="${ZOPE_HTTP_PORT:-8080}"
START_TIMEOUT="${START_TIMEOUT:-300}"
STOP_TIMEOUT="${STOP_TIMEOUT:-120}"
SEED_DIR="${SEED_DIR:-/app/seed}"

export ADMIN_USER ADMIN_PASSWORD

echo "=== seeding ${SITE_ID} (user ${ADMIN_USER}) ==="

# The entrypoint execs ZServer, so $! is the server itself and a TERM to it is
# a real Zope shutdown rather than a shell being killed out from under it.
/docker-entrypoint.sh start &
ZOPE_PID=$!

# Any exit from here on must not leave a half-written database behind: a
# partial Data.fs baked into an image would fail at RUN time, far from here.
cleanup() {
    if kill -0 "${ZOPE_PID}" 2>/dev/null; then
        kill -TERM "${ZOPE_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

echo "waiting for HTTP on :${PORT} (max ${START_TIMEOUT}s)..."
elapsed=0
until curl -sf -o /dev/null "http://127.0.0.1:${PORT}/"; do
    if ! kill -0 "${ZOPE_PID}" 2>/dev/null; then
        echo "FAIL: Zope exited before answering HTTP" >&2
        exit 1
    fi
    if [ "${elapsed}" -ge "${START_TIMEOUT}" ]; then
        echo "FAIL: no HTTP answer within ${START_TIMEOUT}s" >&2
        exit 1
    fi
    sleep 3
    elapsed=$((elapsed + 3))
done
echo "OK: instance is up"

SITE_TITLE="${SITE_TITLE:-Plone demo}" \
    create-plone-site.sh "http://127.0.0.1:${PORT}" \
    "${SITE_ID}" "${ADMIN_USER}" "${ADMIN_PASSWORD}"

# Clean shutdown, then verify it: copying a FileStorage out from under a live
# ZServer is how you bake a half-flushed transaction into an image.
echo "stopping Zope (max ${STOP_TIMEOUT}s)..."
kill -TERM "${ZOPE_PID}"
elapsed=0
while kill -0 "${ZOPE_PID}" 2>/dev/null; do
    if [ "${elapsed}" -ge "${STOP_TIMEOUT}" ]; then
        echo "FAIL: Zope did not shut down within ${STOP_TIMEOUT}s" >&2
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done
trap - EXIT INT TERM
echo "OK: Zope stopped after ${elapsed}s"

# Evidence that the storage was closed and not merely killed: FileStorage
# writes Data.fs.index during a clean close, and does not if it dies. Do NOT
# use Data.fs.lock for this — [V 2026-08-20] it survives an ordinary clean
# stop/start cycle too, so testing it produces a warning on every good build.
if [ ! -f /data/filestorage/Data.fs.index ]; then
    echo "FAIL: no Data.fs.index after shutdown — the storage was not closed" >&2
    exit 1
fi

mkdir -p "${SEED_DIR}"
cp /data/filestorage/Data.fs "${SEED_DIR}/Data.fs"

# Only Data.fs is kept. Data.fs.index is a cache that Zope rebuilds on first
# open, and baking a stale one is worse than baking none.
#
# Blobs are NOT kept, and that is safe only for as long as the seeded site has
# none: create-plone-site.sh creates the site and no content, and a bare Plone
# site has no File or Image. The day something here does create one, 4.0+ would
# write it to /data/blobstorage and this copy would leave it behind — shipping
# a demo image whose database references a blob that does not exist. That is
# the same silent failure the var/ redirect was introduced to end, so assert it
# rather than trusting the comment to be read.
if [ -d /data/blobstorage ] && [ -n "$(find /data/blobstorage -name '*.blob' -print -quit)" ]; then
    echo "FAIL: the seeded site has blobs, and only Data.fs is baked into the image" >&2
    echo "      carry /data/blobstorage into ${SEED_DIR} as well before removing this" >&2
    exit 1
fi

SEED_BYTES=$(wc -c < "${SEED_DIR}/Data.fs" | tr -d ' ')
if [ "${SEED_BYTES}" -lt 100000 ]; then
    echo "FAIL: seeded Data.fs is only ${SEED_BYTES} bytes — no site in it" >&2
    exit 1
fi
echo "OK: seeded ${SEED_DIR}/Data.fs (${SEED_BYTES} bytes)"
