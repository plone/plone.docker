#!/bin/sh
# Install a buildout-era Plone (3.1+) from a UnifiedInstaller tarball, offline.
#
# Usage: build-plone-buildout.sh <installer-tgz> <version> <python-binary> <home>
#   e.g. build-plone-buildout.sh /dist/installer.tgz 3.1.7 \
#            /opt/python2.4/bin/python2.4 /app
#
# Why a UnifiedInstaller rather than a product bundle:
#   From 3.1 on there is no full Plone-<v>.tar.gz. dist.plone.org carries only
#   PloneBase-3.1.x (the stripped core, no dependency products), and its
#   /release/ tree starts at 3.2. The UnifiedInstaller ships
#   packages/buildout-cache.tar.bz2, which is a COMPLETE offline cache: every
#   old-style product tarball, Zope itself, and pre-built py2.4 eggs including
#   zc.buildout and all the plone.recipe.* recipes. That makes the build fully
#   deterministic and keeps the 2008-era toolchain off the network entirely —
#   which matters because it cannot negotiate modern TLS.
#
# The sequence below is taken from the installer's OWN helper_scripts/
# standalone-mode.sh, not invented: copy standalone_template, substitute
# __TARGET__ / __PASSWORD__, strip the root-only chown commands, then run
# `bin/buildout -No` (-N = don't look for newer, -o = offline).
set -eu

SRC="${1:?usage: build-plone-buildout.sh <installer-tgz> <version> <python> <home>}"
VERSION="${2:?missing version}"
PYTHON="${3:?missing python binary}"
HOME_DIR="${4:?missing plone home}"

UI="/tmp/ui-${VERSION}"
INSTANCE="${HOME_DIR}/instance"

mkdir -p "${UI}"
tar -xzf "${SRC}" -C "${UI}" --strip-components=1

# --- the offline cache ------------------------------------------------------
mkdir -p "${HOME_DIR}"
tar -xjf "${UI}/packages/buildout-cache.tar.bz2" -C "${HOME_DIR}"
test -d "${HOME_DIR}/buildout-cache/eggs"
test -d "${HOME_DIR}/buildout-cache/downloads"

# --- the instance skeleton --------------------------------------------------
# [V 2026-08-20] The installer changed layout between 3.1 and 3.2:
#
#   3.1     standalone_template/           — a complete instance dir, buildout.cfg included
#   3.2+    base_skeleton/                 — instance dir WITHOUT a buildout.cfg
#           buildout_templates/standalone.cfg — the buildout.cfg to drop in
#
# The 3.2+ shape is the one the official plone/plone.docker images consume for
# 4.3, so it is the shape that persists. Detect rather than assume, and fail
# loudly on anything else.
if [ -f "${UI}/standalone_template/buildout.cfg" ]; then
    echo "installer layout: standalone_template (3.1-era)"
    cp -r "${UI}/standalone_template" "${INSTANCE}"
elif [ -d "${UI}/base_skeleton" ] && [ -f "${UI}/buildout_templates/standalone.cfg" ]; then
    echo "installer layout: base_skeleton + buildout_templates (3.2+)"
    cp -r "${UI}/base_skeleton" "${INSTANCE}"
    cp "${UI}/buildout_templates/standalone.cfg" "${INSTANCE}/buildout.cfg"

    # [V 2026-08-20] 4.0+ splits the configuration in two: standalone.cfg opens
    # with `extends = base.cfg versions.cfg`, and base.cfg is NOT part of
    # base_skeleton — it is a sibling template that create_instance.py copies
    # in. Without it buildout dies at startup with
    #   IOError: [Errno 2] No such file or directory: '<instance>/base.cfg'
    # 3.2 and 3.3 ship only cluster.cfg + standalone.cfg, so this loop is a
    # no-op there. cluster.cfg is the ZEO variant and is deliberately skipped.
    for tpl in "${UI}"/buildout_templates/*.cfg; do
        name="$(basename "${tpl}")"
        case "${name}" in
            standalone.cfg|cluster.cfg) continue ;;
        esac
        cp "${tpl}" "${INSTANCE}/${name}"
        echo "copied extra template: ${name}"
    done

    # [V 2026-08-20] base.cfg is shared between the standalone and cluster (ZEO)
    # layouts, so it always defines the ZEO sections. create_instance.py deletes
    # FOUR of them for a standalone install:
    #     del buildout['zeoserver'] / ['client1'] / ['client2'] / ['chown-zeo']
    # and all four are required, because plone.recipe.unifiedinstaller walks
    # those sections while initialising rather than ignoring parts it will not
    # build. Removing only [zeoserver] simply moves the error along:
    #     Error: Referenced option does not exist: buildout zeo-address   (none removed)
    #     Error: The referenced section, 'zeoserver', was not defined.    (only zeoserver removed)
    # the second coming from [client1]'s ${zeoserver:blob-storage}.
    if [ -f "${INSTANCE}/base.cfg" ] && grep -q '^\[zeoserver\]' "${INSTANCE}/base.cfg"; then
        awk '/^\[/ {
                 skip = ($0 == "[zeoserver]" || $0 == "[client1]" ||
                         $0 == "[client2]"  || $0 == "[chown-zeo]")
             }
             !skip' "${INSTANCE}/base.cfg" > "${INSTANCE}/base.cfg.tmp"
        mv "${INSTANCE}/base.cfg.tmp" "${INSTANCE}/base.cfg"
        for sect in zeoserver client1 client2 chown-zeo; do
            test "$(grep -c "^\[${sect}\]" "${INSTANCE}/base.cfg")" = "0"
        done
        echo "removed ZEO sections from base.cfg (standalone install)"
    fi
else
    echo "FATAL: unrecognised UnifiedInstaller layout in ${UI}" >&2
    ls -1 "${UI}" >&2
    exit 1
fi
cd "${INSTANCE}"

# Substitute the installer's placeholders. The password here is a placeholder
# only: plone.recipe.zope2instance writes it as the INITIAL emergency user, and
# the entrypoint rewrites that at runtime from ADMIN_USER/ADMIN_PASSWORD.
#
# [V 2026-08-20] How the buildout cache is located changes again at 4.0:
#
#   3.1-3.3  the template carries __TARGET__ placeholders for eggs-directory,
#            download-cache and (3.2+) zope-directory — substitute them.
#   4.0+     the template has NO __TARGET__ at all. create_instance.py ADDS
#            eggs-directory / download-cache / extends-cache to [buildout]
#            instead, so we have to inject them rather than substitute.
#
# Getting this wrong is not subtle — without the cache paths, buildout would try
# to reach PyPI over TLS the interpreter cannot speak.
if [ "$(grep -c '__TARGET__' buildout.cfg)" -ge 1 ]; then
    echo "cache paths: substituting __TARGET__"
    sed -i "s|__TARGET__|${HOME_DIR}|g" buildout.cfg
elif grep -qs '^eggs-directory' "${INSTANCE}"/*.cfg; then
    # [V 2026-08-20] 4.x needs NO substitution here: base.cfg already declares
    #     eggs-directory=../buildout-cache/eggs
    #     download-cache=../buildout-cache/downloads
    # and buildout resolves those relative to the buildout directory, so from
    # /app/instance they land on /app/buildout-cache/* — exactly right.
    #
    # An earlier version injected ABSOLUTE paths into [buildout] here. That was
    # worse than useless: it broke recipe loading with
    #   AttributeError: 'NoneType' object has no attribute 'endswith'
    # from easy_install's _call_easy_install, i.e. a None destination directory.
    # Leave the vendor's own configuration alone.
    echo "cache paths: already declared by the template, left alone"
    grep -hs '^\(eggs-directory\|download-cache\)' "${INSTANCE}"/*.cfg | sed 's/^/  /'
else
    echo "cache paths: injecting into [buildout] (no placeholder, none declared)"
    test "$(grep -c '^\[buildout\]' buildout.cfg)" = "1"

    # Use sed's `r` (read file after match) rather than a multi-line `s`
    # replacement. [V 2026-08-20] A multi-line replacement written with
    # backslash-newline inside double quotes does NOT work: the shell treats
    # backslash-newline as a line continuation and removes it, so all three
    # settings collapse onto the "[buildout]" line as one string and the
    # anchored assertion below silently reports zero. `r` needs no escaping.
    cat > /tmp/cache.cfg <<EOF
eggs-directory = ${HOME_DIR}/buildout-cache/eggs
download-cache = ${HOME_DIR}/buildout-cache/downloads
extends-cache = ${HOME_DIR}/buildout-cache/downloads/extends
EOF
    sed -i "/^\[buildout\]/r /tmp/cache.cfg" buildout.cfg
    rm -f /tmp/cache.cfg
    test "$(grep -c "^eggs-directory = ${HOME_DIR}/buildout-cache/eggs$" buildout.cfg)" = "1"
fi

# The password is a placeholder only: plone.recipe.zope2instance writes it as
# the INITIAL emergency user, and the entrypoint rewrites that at runtime from
# ADMIN_USER/ADMIN_PASSWORD. Note 4.x spells it "user=admin:__PASSWORD__" with
# no spaces, so match the placeholder itself rather than the whole assignment.
test "$(grep -c '__PASSWORD__' buildout.cfg)" = "1"
sed -i "s|__PASSWORD__|placeholder|" buildout.cfg

# Non-root install: strip the chown commands, as create_instance.py does.
sed -i 's|^ *chown -R.*$||; s|^ *find .*$||' buildout.cfg

# effective-user has to be handled differently per era, and guessing wrong is a
# hard buildout failure either way:
#
#   3.x  the key sits in [instance]; create_instance.py DELETES it for a
#        non-root install. Nothing else refers to it.
#   4.x  the key sits in [buildout] and base.cfg refers to it three times as
#        ${buildout:effective-user}; create_instance.py SUBSTITUTES it
#        unconditionally. Deleting it there yields
#        "Error: Referenced option does not exist: buildout effective-user".
#
# So: substitute when something references it, delete when nothing does. The
# runtime user is always `plone` in these images.
# shellcheck disable=SC2016  # the literal string ${buildout:effective-user} is
# what we are searching FOR; expanding it here would be the bug.
if grep -Fqs '${buildout:effective-user}' "${INSTANCE}"/*.cfg; then
    echo "effective-user: referenced elsewhere, substituting 'plone'"
    sed -i 's|__CLIENT_USER__|plone|' buildout.cfg
else
    echo "effective-user: unreferenced, removing (3.x behaviour)"
    sed -i '/^effective-user *= *__CLIENT_USER__/d' buildout.cfg
fi

# A leftover placeholder on a LIVE line would reach Zope as a literal value, so
# make that a build failure rather than a confusing runtime error. Commented
# placeholders are fine and expected — 3.1's template ships
# "#effective-user = __EFFECTIVE_USER__" as documentation.
test "$(grep -c '^[^#;]*__[A-Z_]*__' buildout.cfg)" = "0"

# [V 2026-08-20] The [unifiedinstaller] part is deliberately LEFT ALONE.
# Removing it from `parts` does not stop it: buildout still reports "Installing
# unifiedinstaller" and generates bin/plonectl, because the section is reached
# through another part's references rather than the parts list. Rather than keep
# a sed that looks effective and is not, it runs — bin/plonectl is a restart /
# status wrapper that is simply unused in a container, and harmless.

# --- bin/buildout -----------------------------------------------------------
# The shipped bin/buildout is regenerated rather than patched: it hardcodes
# "#!__TARGET__/Python-2.4/bin/python" and references
# setuptools-0.6c8-py2.4.egg, but the cache actually ships 0.6c9 — the 0.6c8
# path simply does not exist, and install.sh papers over that by installing
# setuptools into the interpreter separately. Discovering the real egg names
# from the cache is both simpler and self-correcting across versions.
# [V 2026-08-20] The setuptools provider changes at 4.0. The caches ship:
#   3.1 / 3.2 / 3.3   setuptools-*.egg only
#   4.0 / 4.1         distribute-*.egg only  (distribute is the setuptools fork)
#   4.2               BOTH
# The vendor's own create_instance.py resolves this with findEgg('distribute')
# for the 4.x line, so preferring distribute when present matches upstream in
# every case — including 4.2, where both are available.
EGGS_DIR="${HOME_DIR}/buildout-cache/eggs"
SETUPTOOLS_EGG="$(find "${EGGS_DIR}" -maxdepth 1 -name 'distribute-*.egg' | head -1)"
if [ -z "${SETUPTOOLS_EGG}" ]; then
    SETUPTOOLS_EGG="$(find "${EGGS_DIR}" -maxdepth 1 -name 'setuptools-*.egg' | head -1)"
fi
BUILDOUT_EGG="$(find "${EGGS_DIR}" -maxdepth 1 -name 'zc.buildout-*.egg' | head -1)"
if [ -z "${SETUPTOOLS_EGG}" ] || [ -z "${BUILDOUT_EGG}" ]; then
    echo "FATAL: no distribute/setuptools or zc.buildout egg in ${EGGS_DIR}" >&2
    find "${EGGS_DIR}" -maxdepth 1 -name '*.egg' | head -20 >&2
    exit 1
fi
echo "bootstrap eggs: $(basename "${SETUPTOOLS_EGG}") $(basename "${BUILDOUT_EGG}")"

cat > bin/buildout <<EOF
#!${PYTHON}
import sys
sys.path[0:0] = [
  '${SETUPTOOLS_EGG}',
  '${BUILDOUT_EGG}',
  ]
import zc.buildout.buildout
if __name__ == '__main__':
    zc.buildout.buildout.main()
EOF
chmod 755 bin/buildout

# --- run it, offline --------------------------------------------------------
# [V 2026-08-20] The offline invocation is NOT the same across the series, and
# using the wrong one fails in a thoroughly misleading way. Taken from each
# installer's own helper scripts:
#
#   3.1  standalone-mode.sh   bin/buildout -No
#   3.2  create_instance.py   bin/buildout -No
#   3.3  create_instance.py   bin/buildout -NoU
#   4.x  create_instance.py   bin/buildout -NU buildout:install-from-cache=true
#
# With plain -No, Plone 4 dies loading plone.recipe.zope2instance:
#   Getting distribution for 'Zope2==2.12.19'.
#   AttributeError: 'NoneType' object has no attribute 'endswith'
# because Zope2 ships only as downloads/dist/Zope2-<v>.zip and has to be BUILT
# from the cache — which is exactly what install-from-cache enables. The error
# points at easy_install internals and says nothing about the missing flag.
#
# Detect from the installer rather than branching on version, so a future
# directory picks up whatever its own installer prescribes.
if grep -rqs 'install-from-cache' "${UI}/helper_scripts"; then
    echo "buildout: -NU buildout:install-from-cache=true (4.x style)"
    ./bin/buildout -NU buildout:install-from-cache=true
else
    echo "buildout: -No (3.x style)"
    ./bin/buildout -No
fi

# A buildout that "succeeds" without producing a runnable instance has not
# actually done its job.
#
# [V 2026-08-20] Do NOT assert parts/plone here, even though 3.1's own
# standalone-mode.sh does: from 3.2 on Plone is pulled in as eggs and there is
# no [plone] part at all. The universal artifacts are the instance script and
# the generated zope.conf, so those are what get checked.
test -x bin/instance
test -f parts/instance/etc/zope.conf

# --- point the instance's state at /data ------------------------------------
# [V 2026-08-20] Unlike the tarball images, zope.conf here is GENERATED by
# plone.recipe.zope2instance and would be rewritten by any later buildout run,
# so editing it in place is the wrong layer. Redirecting var/ at the filesystem
# level survives that.
#
# The WHOLE of var/ is the volume, not a hand-picked pair of subdirectories.
# [V 2026-08-21] This is the shape plone/plone-backend uses -- `/app/var ->
# /data`, with blobstorage, cache, filestorage and logs inside it -- and it is
# the only version of this that is safe against a NEW state directory
# appearing. Symlinking a list meant the list had to be right: 4.0 introduced
# `blob-dir /app/instance/var/blobstorage`, which was not on it, so a one-shot
# `upgrade` container wrote blobs into a layer that vanished on exit and
# committed a database referencing blobs that no longer existed.
#
# [V 2026-08-21] The zdaemon objection to this does not hold. var/ also carries
# instance.pid, instance.lock and CLIENTHOME, so they move into the volume too;
# a container SIGKILLed with all three left behind restarts healthy and serves
# its content, on both 3.3 and 4.2.
mkdir -p /data
# ${INSTANCE:?}, not ${INSTANCE}: an unset INSTANCE would make this `rm -rf
# /var` and take out the builder's own /var. shellcheck SC2115.
rm -rf "${INSTANCE:?}/var"
ln -s /data "${INSTANCE}/var"

# The real guard is not that the symlink exists, but that Zope will actually
# USE it. Rather than asserting a fixed pair of paths -- the very thing that
# let blob-dir through -- assert that EVERY storage location the generated
# zope.conf declares resolves inside /data. A future layout that moved one
# elsewhere becomes a build failure instead of a container quietly writing
# state outside the volume.
CONF="${INSTANCE}/parts/instance/etc/zope.conf"
grep -q "${INSTANCE}/var/filestorage/Data.fs" "${CONF}"
grep -q "${INSTANCE}/var/log/" "${CONF}"

# `path` covers <filestorage> and the <logfile> blocks, `blob-dir` the 4.x
# <blobstorage> wrapper. Checked on the DECLARED string, not on readlink -f: at
# build time /data is an empty directory, so resolving a path that does not
# exist yet would say nothing useful.
#
# The delimiter is `#`, NOT `|`: with `|` the alternation below closes the
# regex at `(path` and the expression matches nothing at all -- silently, exit
# 0, which reads as "every path is fine" and is exactly the failure this guard
# exists to prevent.
sed -nE 's#^[[:space:]]*(path|blob-dir)[[:space:]]+([^[:space:]]+).*#\2#p' "${CONF}" |
    while read -r declared; do
        case "${declared}" in
            "${INSTANCE}"/var/* | /data/*) ;;
            *)
                echo "FATAL: zope.conf stores state outside the volume: ${declared}" >&2
                exit 1
                ;;
        esac
    done

cd /
rm -rf "${UI}"

# Downloads are only needed during the build; the eggs are still referenced by
# the generated scripts at runtime, so only the tarball cache is dropped.
rm -rf "${HOME_DIR}/buildout-cache/downloads"
