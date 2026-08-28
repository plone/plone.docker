#!/bin/sh
# Shared entrypoint for tarball-era Plone images (Zope 2.7-2.10).
# Expects: $ZOPE_HOME, $INSTANCE_HOME, $PYTHON, $ZOPE_HTTP_PORT (default 8080)
set -e

ZOPE_HTTP_PORT="${ZOPE_HTTP_PORT:-8080}"
CONF="${INSTANCE_HOME}/etc/zope.conf"

# /data is a volume: (re)create the expected layout on every start.
mkdir -p /data/filestorage /data/log

# -demo images only: install the pre-built database on first start.
#
# The site is created at BUILD time and the resulting Data.fs is baked in at
# /app/seed/Data.fs — it cannot be baked at /data, because /data is a VOLUME
# and anything a later layer writes there is discarded. Seeding here, before
# the inituser block below, is what makes that block correctly skip itself:
# the seeded database already carries its admin user.
#
# Base images have no /app/seed, so this is a no-op for them.
# The ZEO_ADDRESS guard is not tidiness: under ZEO the storage is remote, so a
# seeded /data/filestorage/Data.fs is never opened, and the reset-admin-password
# step below would then be applied to the WRONG database.
if [ -n "${ZEO_ADDRESS:-}" ] && [ -f /app/seed/Data.fs ]; then
    echo "ZEO_ADDRESS is set: not seeding the demo database (the storage is remote)" >&2
fi
if [ -z "${ZEO_ADDRESS:-}" ] && [ ! -f /data/filestorage/Data.fs ] && [ -f /app/seed/Data.fs ]; then
    echo "seeding /data/filestorage/Data.fs from the demo database"
    cp /app/seed/Data.fs /data/filestorage/Data.fs
    # [V 2026-08-20] The leftover inituser MUST go, and this is not tidiness.
    # Zope applies inituser whenever the file exists — it does NOT check first
    # whether the database already has users — and then deletes it. A -demo
    # image inherits the base image's placeholder inituser, so without this the
    # seeded admin was silently overwritten by mkzopeinstance's build-time
    # placeholder: the site was there and correct, and no password worked.
    rm -f "${INSTANCE_HOME}/inituser"
    SEEDED=1
fi

# Zope <4 has no env interpolation in zope.conf; template the port at start.
# The mkzopeinstance default is "address 8080" inside <http-server>.
#
# [V 2026-08-20] The substitution MUST be confined to the <http-server> block.
# Zope 2.7's mkzopeinstance writes a second uncommented server block:
#
#     <http-server>          <ftp-server>
#       address 8080           address 8021
#     </http-server>         </ftp-server>
#
# so an unscoped `s|address N|address $PORT|` rewrote the FTP port to 8080 as
# well, and Zope died at startup binding the same port twice:
#   ZConfig.ConfigurationError: There was a problem starting a server of type
#   "FTPServer" ... (Address already in use)
# Zope 2.8 and 2.9 emit only <http-server>, which is why this stayed latent
# until the 2.0 image was built.
sed -i "/^[[:space:]]*<http-server>/,/^[[:space:]]*<\/http-server>/ \
s|^\([[:space:]]*address[[:space:]]\+\)[0-9.:]*[0-9]\+|\1${ZOPE_HTTP_PORT}|" "${CONF}"

# ZEO client, when ZEO_ADDRESS is set; a silent no-op otherwise. Runs AFTER the
# port templating above and before anything opens the database.
/app/configure-zeo.sh "${CONF}" "${INSTANCE_HOME}/var"

# First run against an empty /data: write the emergency user so the admin can
# log in. Once a Data.fs exists, inituser is ignored by Zope anyway; we also
# skip rewriting it so an unset ADMIN_PASSWORD never locks out a restart.
# Whether to write inituser at all.
#
# Without ZEO the question is "is /data empty": once a Data.fs exists, Zope has
# its users already. Under ZEO there is no local Data.fs to ask, and answering
# it against a remote storage is not cheap. Writing inituser anyway is NOT
# harmless — [V 2026-08-20] Zope applies it whenever the file EXISTS, without
# checking whether the database already has users — so every client start would
# re-apply it to the shared database and clobber a changed password. Under ZEO
# it is therefore written only when the operator explicitly asks for it by
# supplying ADMIN_PASSWORD, and removed otherwise.
WRITE_INITUSER=0
if [ -n "${ZEO_ADDRESS:-}" ]; then
    if [ -n "${ADMIN_PASSWORD:-}" ]; then
        echo "ZEO_ADDRESS is set and ADMIN_PASSWORD supplied: seeding the emergency user"
        WRITE_INITUSER=1
    else
        rm -f "${INSTANCE_HOME}/inituser"
    fi
elif [ ! -f /data/filestorage/Data.fs ]; then
    WRITE_INITUSER=1
fi

if [ "${WRITE_INITUSER}" = "1" ]; then
    ADMIN_USER="${ADMIN_USER:-admin}"
    if [ -z "${ADMIN_PASSWORD}" ]; then
        echo "WARNING: ADMIN_PASSWORD not set; using 'admin'. Do not expose this container." >&2
        ADMIN_PASSWORD="admin"
    fi
    "${PYTHON}" "${ZOPE_HOME}/bin/zpasswd.py" \
        -u "${ADMIN_USER}" -p "${ADMIN_PASSWORD}" \
        "${INSTANCE_HOME}/inituser"
fi

# -demo images only: apply ADMIN_USER/ADMIN_PASSWORD to the seeded database.
#
# inituser cannot do this. Zope consults it only while CREATING a database, and
# a demo image ships one already made — so without this step the credentials
# baked in at build time would be the only ones that ever worked, and a
# perfectly ordinary `-e ADMIN_PASSWORD=...` would be silently ineffective.
#
# Runs before the exec below, so nothing holds the ZODB lock yet.
if [ "${SEEDED:-0}" = "1" ] && [ -f /app/seed/reset-admin-password.py ]; then
    reset_out=$("${INSTANCE_HOME}/bin/zopectl" run \
        /app/seed/reset-admin-password.py 2>&1) || true
    # `zopectl run` does not reliably propagate the script's exit status, so
    # trust the sentinel the script prints and nothing else. Treating a silent
    # failure as success here would hand out an image nobody can log into.
    if ! printf '%s' "${reset_out}" | grep -q 'PASSWORD-RESET-OK'; then
        echo "FATAL: could not apply ADMIN_PASSWORD to the seeded database" >&2
        printf '%s\n' "${reset_out}" >&2
        exit 1
    fi
    printf '%s\n' "${reset_out}" | grep -v 'PASSWORD-RESET-OK' || true
fi

case "$1" in
    start)
        # runzope stays in the foreground: proper PID 1, signals reach ZServer.
        exec "${INSTANCE_HOME}/bin/runzope"
        ;;
    debug)
        exec "${INSTANCE_HOME}/bin/zopectl" debug
        ;;
    run)
        # Forward EVERY argument. `$2` alone silently drops the script's own
        # arguments, and passes an empty string when no script is named.
        shift
        exec "${INSTANCE_HOME}/bin/zopectl" run "$@"
        ;;
    upgrade)
        # Deliberately NOT exec'd: the output has to be read.
        #
        # `zopectl run` does not reliably propagate the script's exit status —
        # the same reason reset-admin-password.py prints a sentinel — so a
        # failed migration exits 0 and looks exactly like a successful one.
        # Verified [V 2026-08-21]: a 3.3 -> 4.0 hop that logged "Migration has
        # failed" still exited 0. Trust the sentinel and nothing else.
        upgrade_out=$("${INSTANCE_HOME}/bin/zopectl" run /app/upgrade-plone.py 2>&1) || true
        printf '%s\n' "${upgrade_out}" | grep -v 'UPGRADE-OK' || true
        if ! printf '%s' "${upgrade_out}" | grep -q 'UPGRADE-OK'; then
            echo "FATAL: the upgrade did not complete; the database is unchanged" >&2
            exit 1
        fi
        exit 0
        ;;
    *)
        exec "$@"
        ;;
esac
