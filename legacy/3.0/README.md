# Plone 3.0 legacy image

Plone 3.0.5 on Zope 2.10.13 / Python 2.4.6. The **last tarball-era release** —
3.2 onwards require buildout, which needs a different template.

**Not for production.** Zope 2.10 has known, unpatched vulnerabilities. This
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 3.0/Dockerfile -t plone-legacy:3.0.5 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone30-data:/data plone-legacy:3.0.5
```

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG (no freetype/`_imagingft`) |
| ElementTree | 1.2.7 (required by Plone 3; see below) |

## Two ways this differs from the 2.x images

Both were verified against the actual bundle, not assumed from the 2.x pattern.

### 1. The bundle has a different shape

Where every 2.x bundle was one directory per product at the top level, 3.0 is:

```
Plone-3.0.5/
  Products/<41 product dirs>
  lib/python/{archetypes,five,kss,plone,wicked}
  INSTALL.txt README.txt RELEASENOTES.txt
```

`INSTALL.txt` is explicit: *"The Zope Products are installed in the usual
location: the Products directory of the Zope instance. Python package may be
installed in the lib/python directory in the Zope instance"*. Both copies are
made, and both are asserted in the Dockerfile — a `--strip-components=1` copy
of the top level alone would produce an instance that starts with half of
Plone missing and no error.

`<instance>/lib/python` is genuinely on `sys.path`: Zope 2.10's
`Zope2/Startup/handlers.py:187` reads *"always insert instancehome/lib/python"*,
and `mkzopeinstance` creates that directory in its skeleton.

### 2. ElementTree is a new hard dependency

`INSTALL.txt` says *"The python ElementTree package is now required"*, and it
means it. `CMFPlone/setup/dependencies.py` only logs when it is missing, but
`Products/Marshall/handlers/atxml.py:51-54` does

```python
try:
    from celementtree import ElementTree
except ImportError:
    from elementtree import ElementTree
```

with no outer guard, so with neither package installed the module raises
`ImportError` and Marshall fails to load. Python 2.5 absorbed this as
`xml.etree`, but these images run 2.4.

Plone's docs point at `effbot.org` for the download, which is dead (404) — the
same dead end as PIL. `dist.plone.org/thirdparty/` carries
`elementtree-1.2.7-20070827-preview.zip`, and that is what is installed.

## Validated facts / hypotheses

- **[V 2026-08-20]** **3.0.5 is the last full bundle, not 3.0.6.** The matrix
  listed `3.0.6*`. `PloneBase-3.0.6.tar.gz` exists (1.0 MB) but there is no
  `Plone-3.0.6.tar.gz`: the 3.0.6 roll shipped only as PloneBase, the stripped
  core without dependency products. The last full `Plone-*.tar.gz` is 3.0.5
  (12.6 MB, 41 products). Note also that unlike the 2.x bundles these live at
  the **dist.plone.org root**, not under `/archive/`, which holds only
  UnifiedInstaller tarballs for this series.
- **[V 2026-08-20]** `Zope-2.10.13-final.tgz` (7.4 MB) is downloadable from
  `old.zope.dev`, unpacks to `Zope-2.10.13-final/` with a top-level
  `./configure`, and that configure declares `TARGET="2.4.6"` — exactly the
  interpreter these images already build. Plone 3.0 requires Zope 2.10.4+.
- **[V 2026-08-20]** Python 2.4.6, PIL 1.1.6 and Zope 2.10.13 all build through
  the shared scripts with no 3.0-specific changes. `-fcommon` again sufficient.
- **[V 2026-08-20]** **A guard failed for the wrong reason: CRLF.** The
  elementtree zip ships `setup.py` with `\r\n` endings, so every line really
  ends `...setup\r`. GNU grep anchors `$` after the `\n` only, so the strict
  pattern `'^from distutils.core import setup$'` matched **zero** times and the
  build failed on its own assertion. Confirmed in-container: GNU grep 3.8 on
  bookworm returns 0 for the strict pattern and 1 once `\r` is accounted for —
  while the developer's host grep is lenient and matched, hiding it.
  `build-elementtree.sh` now normalises line endings before asserting.
  **Test text guards against the container's grep, not the host's.**
- **[V 2026-08-20]** `old.zope.dev` is intermittently slow and returned a
  Cloudflare **522** on the first build attempt, then served the same URL fine
  (16.6 s) on retry. Nothing in the image is wrong when this happens — just
  build again. Worth knowing before debugging a phantom failure.
- **[V 2026-08-20]** The site factory matches 2.5, not 2.1: `/manage_main`
  links `CMFPlone/addPloneSiteForm`, whose form posts to `addPloneSite`. The
  smoke test's discovery handled 3.0 with no change.
- **[V 2026-08-20]** 42 entries land in `Products/` (41 product dirs plus a
  loose file) and 6 in `lib/python`. Zero products fail to import or install,
  and a Plone 3.0 site can be created and rendered (~20 kB carrying the Plone
  `generator` meta tag). Passes twice consecutively.

## Smoke test (CI gate)

```sh
make test-3.0                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-3.0  # also creates a Plone site and checks its markup
```
