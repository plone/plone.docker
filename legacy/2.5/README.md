# Plone 2.5 legacy image

Plone 2.5.4-2 on Zope 2.9.12 / Python 2.4.6. Tarball-era template (no buildout).

**Not for production.** Zope 2.9 has known, unpatched vulnerabilities. This image
exists for content extraction, migration rehearsal, and historical inspection.

The image bundles **PIL 1.1.6** with JPEG and PNG support. As in 2.1, this is not
optional: `CMFPlone/utils.py` line 6 is an unconditional `from PIL import Image`.

## Why the tag says `2.5.4-2`

There is no Plone 2.5.5. The last 2.5.x is 2.5.4, published as two tarballs whose
file lists are byte-for-byte identical; only four files differ. `Plone-2.5.4-2.tar.gz`
is the later roll and the one shipped here, so the image tag matches the
`CMFPlone/version.txt` inside it rather than rounding down to a prettier `2.5.4`.

## Usage

```sh
docker build -f 2.5/Dockerfile -t plone-legacy:2.5.4-2 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone25-data:/data plone-legacy:2.5.4-2
```

To mount an existing site, drop its `Data.fs` at `/data/filestorage/Data.fs`
(and add its third-party products to `/app/instance/Products` via bind mount
or a derived image).

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG (no freetype/`_imagingft`) |

## Validated facts / hypotheses

- **[V 2026-08-20]** **Plone 2.5.5 does not exist.** `dist.plone.org` has no
  2.5.5 in `/archive/`, `/download/` or `/packages/`. The matrix's `2.5.5*` was
  a placeholder and the Makefile pinned a phantom version.
- **[V 2026-08-20]** The two 2.5.4 tarballs have **identical file lists**; only
  `CMFPlone/version.txt`, `CONTENTS.txt`, `CMFPlone/migrations/__init__.py` and
  `ATContentTypes/migration/__init__.py` differ. `-2` (2007-10-09 12:44) is the
  later roll: it registers the `2.5.4-final -> 2.5.4-2` upgrade path and
  corrects an ATContentTypes version string from `1.1.7-devel (svn/unreleased)`
  to `1.1.7-final`. Verified by extracting and diffing both, not by changelog.
- **[V 2026-08-20]** `Zope-2.9.12-final.tgz` (7.1 MB) is downloadable from
  `old.zope.dev/Products/Zope/2.9.12/`, unpacks to `Zope-2.9.12-final/`, and
  ships a top-level `./configure` plus `utilities/mkzopeinstance.py` — the same
  build shape as 2.8.12, so the 2.1 recipe transfers unchanged.
- **[V 2026-08-20]** Python 2.4.6 builds via the shared `build-python2.sh`
  with no 2.5-specific changes; `lib-dynload` has no `*_failed.so`.
- **[V 2026-08-20]** Bundle layout is `Plone-2.5.4-2/<Product>/...`, 38 product
  directories (vs. 20 in 2.0.5 and 32 installed in 2.1.4).
- **[V 2026-08-20]** Zope 2.9.12 C extensions compile with gcc 12 given
  `CFLAGS="-fcommon -fno-strict-aliasing"`. As with 2.8.12, this confirms the
  flag is *sufficient*; it was not re-run without `-fcommon`, so necessity is
  untested.
- **[V 2026-08-20]** **The site factory differs from 2.1** — this is the
  ledger's "do not recall, re-discover" warning coming true on the first new
  version directory:

  | Version | linked from `/manage_main` | form posts to |
  |---|---|---|
  | 2.1.4 | `CMFPlone/addSite` | `manage_addSite` |
  | 2.5.4-2 | `CMFPlone/addPloneSiteForm` | `addPloneSite` |

  `shared/smoke-test.sh` now walks the two steps (find the add-form, read its
  `action`) instead of hardcoding either, so the gate is version-agnostic.
  2.5's form also offers `extension_ids:list`, which the test leaves unset.
- **[V 2026-08-20]** A Plone 2.5 site can be created and rendered: the site
  root serves ~22 kB carrying the Plone `generator` meta tag, and zero products
  fail to import or install.

## Smoke test (CI gate)

```sh
make test-2.5                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-2.5  # also creates a Plone site and checks its markup
```
