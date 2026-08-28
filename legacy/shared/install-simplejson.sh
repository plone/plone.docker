#!/bin/sh
# Install simplejson (pure Python) into a historical CPython 2.x.
#
# Usage: install-simplejson.sh <sdist-tarball> <version> <python-binary>
#   e.g. install-simplejson.sh /dist/simplejson.tar.gz 2.0.9 \
#            /opt/python2.4/bin/python2.4
#
# WHY: Python grew a stdlib `json` only in 2.6. Every image below 4.0 runs
# Python 2.3 or 2.4 and therefore has no JSON support at all — which makes
# scripted content extraction, the entire purpose of these images, needlessly
# painful. 4.0/4.1 (2.6.9) and 4.2 (2.7.18) need nothing.
#
# [V 2026-08-27] Plone 3.3 is deliberately NOT patched: its UnifiedInstaller
# already ships simplejson-2.0.9-py2.4.egg in the buildout-cache AND puts it on
# the instance's sys.path — `bin/instance run` imports it today, verified on the
# built image.
#
# The C `_speedups` extension is deliberately NOT built. simplejson ships a
# complete pure-Python fallback; these images are for archaeology rather than
# throughput; and skipping it keeps the install a plain directory copy with no
# compiler in the loop, identical in the tarball-era and buildout-era images.
#
# [V 2026-08-27] A plain drop-in into site-packages is enough — no buildout
# part, no egg, no .pth. site-packages IS on sys.path for BOTH script runners:
# `zopectl run` (tarball era) and `bin/instance run` (buildout era). Verified by
# mounting the package in and importing it through the entrypoint on 2.5 and
# 3.2; both answered with a working dumps().
#
# VERSION PER INTERPRETER. Chosen by running simplejson's OWN unit suite inside
# these images [V 2026-08-27]:
#
#   Python 2.3  ->  1.9.3   24 tests, 0 failures, 0 errors.
#   Python 2.4  ->  2.0.9   33 tests, 0 failures, 0 errors. Also the exact
#                           version Plone 3.3's own installer shipped.
#
# 2.0.9 does NOT work on Python 2.3: encoder.py does `items.sort(key=...)`, and
# the key= argument is 2.4+, so dumps(sort_keys=True) raises TypeError while
# every other call still works. That is precisely the kind of failure that
# surfaces months later inside somebody's export script, so the gate below
# exercises sort_keys deliberately: pairing the wrong release with an
# interpreter is a BUILD failure here, not a surprise there.
#
# (Two of simplejson's test modules skip on 2.3 because they import `decimal`,
# which is itself 2.4+. That is the interpreter, not simplejson.)
set -eu

SRC="${1:?usage: install-simplejson.sh <sdist-tarball> <version> <python>}"
VERSION="${2:?missing version}"
PYTHON="${3:?missing python binary}"

BUILD="/tmp/simplejson-${VERSION}"

rm -rf "${BUILD}"
tar -xzf "${SRC}" -C /tmp

# A tarball whose top-level directory does not match the declared version means
# the URL and the ARG have drifted apart. Fail here rather than installing a
# different release than the one the Dockerfile claims.
test -d "${BUILD}/simplejson"

# Ask the interpreter where its site-packages is rather than composing the path
# from the version string: the two agree today, but a differently-configured
# prefix would silently install into a directory nothing imports from.
SITE="$("${PYTHON}" -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()')"
test -n "${SITE}"
test -d "${SITE}"

rm -rf "${SITE}/simplejson"
cp -a "${BUILD}/simplejson" "${SITE}/simplejson"

# The speedups are not built; drop the source so the installed package cannot be
# mistaken for a compiled one.
rm -f "${SITE}/simplejson/_speedups.c"

# The installed package must be the version asked for.
GOT="$("${PYTHON}" -c 'import simplejson; print simplejson.__version__')"
if [ "${GOT}" != "${VERSION}" ]; then
    echo "FATAL: installed simplejson ${GOT}, expected ${VERSION}" >&2
    exit 1
fi

# --- Gate -------------------------------------------------------------------
# Assert the behaviour an extraction script actually relies on, not merely that
# the import succeeds. sort_keys is the discriminator between the 2.3-safe and
# the 2.4-only releases (see the header), so it is exercised on purpose.
"${PYTHON}" - <<'PY'
import simplejson

payload = {"b": 2, "a": [1, 2.5, None, True], "s": "plain"}
encoded = simplejson.dumps(payload, sort_keys=True)
assert encoded.startswith('{"a"'), encoded
assert simplejson.loads(encoded) == payload, encoded

# Non-ASCII has to survive the round trip as unicode: Plone content is full of
# it, and a codec-level break here would only show up on real data.
text = simplejson.loads('{"k": "\\u00e7\\u00e3o"}')["k"]
assert isinstance(text, unicode), repr(text)
assert len(text) == 3, repr(text)
assert simplejson.loads(simplejson.dumps({"k": text}))["k"] == text

print "simplejson gate ok:", simplejson.__version__
PY

rm -rf "${BUILD}"
