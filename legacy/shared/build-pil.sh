#!/bin/sh
# Build and install PIL (Python Imaging Library) for a historical CPython 2.x.
#
# Usage: build-pil.sh <src-tarball> <version> <python-binary>
#   e.g. build-pil.sh /dist/pil.tar.gz 1.1.6 /opt/python2.4/bin/python2.4
#
# Why PIL is in these images at all:
#   Plone 2.1.4 and 2.5.4 CMFPlone/utils.py open with an UNCONDITIONAL
#   `from PIL import Image`, so without PIL, CMFPlone / Archetypes /
#   ATContentTypes all fail to import and no Plone site can be created
#   (decisions D2/D4). Plone 2.0.5 guards its only PIL import in Archetypes,
#   so PIL is optional there — but it is bundled anyway so image scaling
#   actually works, rather than silently degrading during a migration.
#
# Source: dist.plone.org/thirdparty. effbot.org is dead (404) and PyPI lists
# PIL 1.1.6 but serves no files, so this is the surviving canonical mirror.
# These tarballs are the Plone-community repackaging, not stock effbot PIL,
# which is what makes patch 1 below necessary.
set -eu

SRC="${1:?usage: build-pil.sh <src-tarball> <version> <python-binary>}"
VERSION="${2:?missing version}"
PYTHON="${3:?missing python binary}"

BUILD="/tmp/PIL-${VERSION}"

tar -xzf "${SRC}" -C /tmp
cd "${BUILD}"

MULTIARCH="$(gcc -print-multiarch)"
test -n "${MULTIARCH}"

# --- Patch 1: drop the setuptools bootstrap ---------------------------------
# The repackaged setup.py calls ez_setup.use_setuptools(), which downloads
# setuptools from PyPI over HTTPS. Our interpreter has no _ssl (see
# build-python2.sh), so that fetch can NEVER succeed. PIL uses setuptools only
# for `setup` and `find_packages`, so dropping to distutils removes the
# dependency outright and keeps the build hermetic.
#
# Do NOT "fix" this by bootstrapping setuptools instead: that reintroduces a
# network fetch mid-build and breaks determinism. (For the record, setuptools
# 1.4.2 is the last release supporting Python 2.4.)
test "$(grep -c '^import ez_setup$' setup.py)" = "1"
test "$(grep -c '^ez_setup\.use_setuptools()$' setup.py)" = "1"
test "$(grep -c '^from setuptools import setup, find_packages$' setup.py)" = "1"

sed -i '/^import ez_setup$/d; /^ez_setup\.use_setuptools()$/d' setup.py
sed -i 's|^from setuptools import setup, find_packages$|from distutils.core import setup\ndef find_packages(): return ["PIL"]|' setup.py

test "$(grep -c ez_setup setup.py)" = "0"

# --- Patch 2: multiarch library roots ---------------------------------------
# The same failure class as Python's own setup.py, but worse: PIL's Linux
# library_dirs is only /usr/local/lib plus <prefix>/lib — it never looks in
# /usr/lib, let alone the triplet dir — so libjpeg and libz go undetected and
# PIL builds SUCCESSFULLY without JPEG and PNG support.
#
# Unlike Python, PIL documents JPEG_ROOT / ZLIB_ROOT as the supported hook for
# exactly this, so no search-path patching is needed.
test "$(grep -c '^JPEG_ROOT = None$' setup.py)" = "1"
test "$(grep -c '^ZLIB_ROOT = None$' setup.py)" = "1"

sed -i "s|^JPEG_ROOT = None$|JPEG_ROOT = \"/usr/lib/${MULTIARCH}\", \"/usr/include\"|" setup.py
sed -i "s|^ZLIB_ROOT = None$|ZLIB_ROOT = \"/usr/lib/${MULTIARCH}\", \"/usr/include\"|" setup.py

test "$(grep -c "JPEG_ROOT = \"/usr/lib/${MULTIARCH}\"" setup.py)" = "1"
test "$(grep -c "ZLIB_ROOT = \"/usr/lib/${MULTIARCH}\"" setup.py)" = "1"

"${PYTHON}" setup.py install > /dev/null

cd /
rm -rf "${BUILD}"

# --- Gate -------------------------------------------------------------------
# Assert a real JPEG and PNG round-trip through thumbnail(ANTIALIAS), not
# merely that `import PIL` succeeds: a PIL built without libjpeg/libz imports
# perfectly well and only fails when an image is actually saved.
"${PYTHON}" -c "\
from PIL import Image; \
im = Image.new('RGB', (200, 120), (30, 90, 160)); \
im.thumbnail((64, 64), Image.ANTIALIAS); \
im.save('/tmp/t.jpg', 'JPEG'); \
im.save('/tmp/t.png', 'PNG'); \
Image.open('/tmp/t.jpg').load(); \
Image.open('/tmp/t.png').load(); \
print 'PIL', Image.VERSION, 'JPEG+PNG ok'"
rm -f /tmp/t.jpg /tmp/t.png
