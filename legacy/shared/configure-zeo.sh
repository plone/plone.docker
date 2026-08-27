#!/bin/sh
# Turn this instance into a ZEO client — when, and only when, ZEO_ADDRESS is set.
#
# Usage: configure-zeo.sh <path to zope.conf> <instance var dir>
#
# CLIENT ONLY, by design. Nothing here starts or configures a ZEO server: point
# ZEO_ADDRESS at one you run yourself. Both eras ship the ZEO package (Zope
# 2.7's lib/python/ZEO, the ZODB3 egg in the buildout images), so a server can
# be run from these same images with `python -m ZEO.runzeo` if you want one.
#
# Modelled on plone.docker's 4.3 docker-initialize.py, reduced to the single
# thing it does that matters here: swap the <zodb_db main> storage block for a
# <zeoclient>. Its other jobs — rewriting buildout, zeopack, the zeoserver conf
# — have no counterpart in these images.
#
# One implementation for all eleven versions, because the two storage shapes
# differ only in nesting:
#
#   1.0 - 3.3   <zodb_db main><filestorage>path …</filestorage></zodb_db>
#   4.0 - 4.2   <zodb_db main><blobstorage>blob-dir …
#                                <filestorage>path …</filestorage>
#                              </blobstorage></zodb_db>
#
# so the block to replace is whichever storage tag opens FIRST, and it ends at
# that tag's own closer — never at the inner </filestorage>.
set -eu

CONF="${1:?usage: configure-zeo.sh <zope.conf> <instance var dir>}"
VAR_DIR="${2:?usage: configure-zeo.sh <zope.conf> <instance var dir>}"

# No ZEO_ADDRESS: leave the instance on its local FileStorage, silently. This
# is the path every existing image and every test already takes.
[ -n "${ZEO_ADDRESS:-}" ] || exit 0

# Already rewritten — a restart of a container whose conf we edited on a first
# start. The anchor is load-bearing: Plone 1.0.6's stock zope.conf ships a
# COMMENTED <zeoclient> example, and an unanchored grep reads that as "already
# a client" and leaves the instance on FileStorage with no warning at all.
if grep -q '^[[:space:]]*<zeoclient>' "${CONF}"; then
    exit 0
fi

ZEO_STORAGE="${ZEO_STORAGE:-1}"
ZEO_CLIENT_CACHE_SIZE="${ZEO_CLIENT_CACHE_SIZE:-128MB}"
ZEO_SHARED_BLOB_DIR="${ZEO_SHARED_BLOB_DIR:-off}"

echo "configuring ZEO client: server ${ZEO_ADDRESS}, storage ${ZEO_STORAGE}"

TMP="${CONF}.zeo.$$"
awk \
    -v address="${ZEO_ADDRESS}" \
    -v storage="${ZEO_STORAGE}" \
    -v cache_size="${ZEO_CLIENT_CACHE_SIZE}" \
    -v shared_blob_dir="${ZEO_SHARED_BLOB_DIR}" \
    -v var_dir="${VAR_DIR}" '
BEGIN { in_main = 0; skipping = 0; closer = ""; blobs = 0; blob_dir = ""; done = 0 }

# Commented lines are never matched by anything below. Plone 1.0.6 ships a
# whole COMMENTED <zodb_db main> example — zeoclient and all — right after the
# live one, and without this the second block is entered as though it were real.
/^[[:space:]]*#/ { print; next }

# Only the FIRST main database is touched, once. A mounted secondary zodb_db,
# if anyone ever adds one, keeps whatever storage it was given.
!in_main && !done && /<zodb_db main>/ { in_main = 1; print; next }

# Whichever storage tag opens first is the one being replaced.
in_main && !skipping && /<blobstorage>/ { skipping = 1; closer = "</blobstorage>"; blobs = 1; next }
in_main && !skipping && /<filestorage>/ { skipping = 1; closer = "</filestorage>"; blobs = 0; next }

# Reuse the blob directory the image already uses rather than inventing a path.
# With shared-blob-dir off this is a local cache, so where it points still
# matters — a wrong path silently costs every blob read a round trip.
skipping && /^[[:space:]]*blob-dir[[:space:]]/ { blob_dir = $2; next }

skipping {
    if (index($0, closer) > 0) {
        skipping = 0
        done = 1
        print "    <zeoclient>"
        print "      server " address
        print "      storage " storage
        print "      name zeostorage"
        print "      var " var_dir
        print "      cache-size " cache_size
        if (blobs) {
            if (blob_dir != "")
                print "      blob-dir " blob_dir
            print "      shared-blob-dir " shared_blob_dir
        }
        print "    </zeoclient>"
    }
    next
}

in_main && /<\/zodb_db>/ { in_main = 0; print; next }
{ print }

END { exit(done ? 0 : 1) }
' "${CONF}" > "${TMP}" || {
    rm -f "${TMP}"
    echo "FATAL: no <zodb_db main> storage block found in ${CONF};" >&2
    echo "       refusing to start a ZEO client against a local FileStorage." >&2
    exit 1
}

mv "${TMP}" "${CONF}"

# Assert the result rather than assume it: a rewrite that produced a conf
# without a live <zeoclient> would start Zope on the wrong storage, and the
# only symptom would be an empty site.
if ! grep -q '^[[:space:]]*<zeoclient>' "${CONF}"; then
    echo "FATAL: ZEO rewrite of ${CONF} produced no <zeoclient>" >&2
    exit 1
fi
echo "OK: ${CONF} now opens the ZEO storage at ${ZEO_ADDRESS}"
