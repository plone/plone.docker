#!/bin/sh
# Install ElementTree for a historical CPython 2.x.
#
# Usage: build-elementtree.sh <src-zip> <version> <python-binary>
#   e.g. build-elementtree.sh /dist/elementtree.zip 1.2.7-20070827-preview \
#            /opt/python2.4/bin/python2.4
#
# Why this is here:
#   Plone 3.0's INSTALL.txt states "The python ElementTree package is now
#   required". It is not merely advisory: Products/Marshall/handlers/atxml.py
#   does
#       try:    from celementtree import ElementTree
#       except ImportError:
#               from elementtree import ElementTree
#   with no outer guard, so with neither package present the module raises
#   ImportError and Marshall fails to load. (CMFPlone/setup/dependencies.py
#   also checks for it, but only logs.)
#
#   Python 2.5 absorbed this as xml.etree, but the tarball-era images that need
#   it run Python 2.4, so it has to be installed separately.
#
# Source: dist.plone.org/thirdparty, the same mirror used for PIL. The upstream
# effbot.org download page that Plone's own docs point at is dead (404).
#
# Unlike PIL, this package is pure Python and uses plain distutils — no
# setuptools bootstrap, no C extension, no multiarch problem.
set -eu

SRC="${1:?usage: build-elementtree.sh <src-zip> <version> <python-binary>}"
VERSION="${2:?missing version}"
PYTHON="${3:?missing python binary}"

BUILD="/tmp/elementtree-${VERSION}"

unzip -q "${SRC}" -d /tmp
test -d "${BUILD}"
cd "${BUILD}"

# [V 2026-08-20] This zip ships setup.py with CRLF line endings, so every line
# really ends "...setup\r". GNU grep anchors $ after the \n only, which means a
# strict '^...setup$' pattern matches ZERO times and the guard below fails the
# build for the wrong reason. (Confirmed: GNU grep 3.8 on bookworm returns 0 for
# the strict pattern and 1 once \r is accounted for. BSD/ugrep on the developer's
# host is lenient here and hides it, so this must be tested in-container.)
# Normalising once up front keeps the assertions exact and readable.
sed -i 's/\r$//' setup.py

# Assert the assumption that this is a distutils package, so a future release
# that switched to setuptools fails loudly here instead of trying to reach PyPI
# over TLS the interpreter does not have.
test "$(grep -c '^from distutils.core import setup$' setup.py)" = "1"
test "$(grep -c 'ez_setup\|setuptools' setup.py)" = "0"

"${PYTHON}" setup.py install > /dev/null

cd /
rm -rf "${BUILD}"

"${PYTHON}" -c "\
from elementtree import ElementTree; \
e = ElementTree.fromstring('<a><b>x</b></a>'); \
assert e.find('b').text == 'x'; \
print 'elementtree', ElementTree.VERSION, 'ok'"
