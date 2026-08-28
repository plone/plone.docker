# Plone 2.1 legacy image

Plone 2.1.4 on Zope 2.8.12 / Python 2.4.6. Tarball-era template (no buildout).

**Not for production.** Zope 2.8 has known, unpatched vulnerabilities. This image
exists for content extraction, migration rehearsal, and historical inspection.

The image bundles **PIL 1.1.6** with JPEG and PNG support. This is not
optional: `CMFPlone/utils.py` line 4 is an unconditional `from PIL import
Image`, so without PIL, CMFPlone, Archetypes and ATContentTypes all fail to
import and no Plone site can be created. All 30 bundled products register with
no import or install errors, and a Plone site can be created end to end.

## Usage

```sh
docker build -f 2.1/Dockerfile -t plone-legacy:2.1.4 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone21-data:/data plone-legacy:2.1.4
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

- **[V]** `Zope-2.8.12-final.tgz` (last 2.8.x, 2010-01-12) is downloadable from
  `old.zope.dev/Products/Zope/2.8.12/` — verified 2026-08-19.
- **[V]** python.org serves all historical source releases, incl. 2.4.6.
- **[V]** `Plone-2.1.4.tar.gz` (2006-09-19) is downloadable from
  `dist.plone.org/archive/` — verified 2026-08-19. The same archive holds the
  final tarballs for 2.0.5, 2.5.4, and 3.0.5, so it is the canonical fetch
  source for the entire tarball era. (Supersedes H1, which assumed Launchpad.)
- **[V 2026-08-20]** Python 2.4.6 compiles on bookworm (gcc 12 / glibc 2.36)
  with the `posix_close` rename + `-fno-strict-aliasing -fwrapv` +
  `--without-cxx` — **plus a multiarch patch that the original H2 missed.**
  Python 2.4 predates Debian multiarch, so its `setup.py` looks for libraries in
  `/usr/lib` while bookworm keeps `libz.so`/`libcrypt.so` only in
  `/usr/lib/x86_64-linux-gnu`. Without the patch, zlib and crypt are silently
  skipped and the gate fails with `ImportError: No module named zlib`. Note that
  `LDFLAGS=-L...` does *not* help: setup.py only honours it on darwin.
  *Gate:* `python2.4 -c "import zlib, sha, md5"` exits 0. **Passes**, with no
  `*_failed.so` left in `lib-dynload`.
- **[V 2026-08-28]** Bundle layout is `Plone-2.1.4/<Product>/...`, one directory
  per product, confirmed with `tar -tzf`. **30** product directories land in
  `Products/`; `CMFPlone/version.txt` reads `2.1.4`. Count directories, not
  entries: `ls` reports 32 because `CONTENTS.txt` and `README.txt` sit
  alongside the products and are not products.
- **[V 2026-08-20]** Zope 2.8 C extensions compile with gcc 12 given
  `CFLAGS="-fcommon -fno-strict-aliasing"`; `make install` succeeds in ~42 s and
  `runzope` binds :8080. Not tested *without* `-fcommon`, so the flag is
  confirmed sufficient, not proven necessary.
- **[V 2026-08-20]** `zpasswd.py -u USER -p PASS FILE` writes a valid
  `inituser`: `/manage_main` returns 200 under basic auth on a fresh volume.
- **[V 2026-08-20]** `runzope` execs through to ZServer, so PID 1 is the Python
  process itself. `docker stop` returns in 0.25 s with exit code 0.
- **[V 2026-08-20]** CMFPlone 2.1.4 cannot be imported without PIL. Resolved by
  bundling PIL 1.1.6 from `dist.plone.org/thirdparty/` — `effbot.org` is dead
  (404) and PyPI lists PIL but serves no files, so that is the surviving
  canonical source. Two traps: the tarball is repackaged for setuptools and
  calls `ez_setup.use_setuptools()`, which cannot work because our Python 2.4
  has no `_ssl` (fixed by dropping to distutils, *not* by bootstrapping
  setuptools, which would reintroduce a network fetch); and PIL searches only
  `/usr/local/lib` and `<prefix>/lib`, so libjpeg/libz go undetected and PIL
  builds *successfully* without JPEG and PNG — fixed via the documented
  `JPEG_ROOT`/`ZLIB_ROOT` hooks.
- **[V 2026-08-20]** A Plone 2.1 site can be created and rendered: POST to
  `manage_addProduct/CMFPlone/manage_addSite` (`id`, `title`,
  `create_userfolder`) returns 302 and the site root serves ~23 kB carrying
  `<meta name="generator" content="Plone - http://plone.org" />`.

## Smoke test (CI gate)

```sh
make test-2.1                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-2.1  # also creates a Plone site and checks its markup
```

The product check is **fatal by default**; set `SMOKE_STRICT_PRODUCTS=0` to
downgrade it to a warning. That default exists because Zope answers HTTP and
authenticates perfectly well with every Plone product broken — the gate passed
on an unusable image before this check was added.

The `debian/eol:etch` fallback (period-correct gcc 4.1, with the fetch stage
keeping old userland off the network) was **not needed**: strategy S1 reached
gate G1 once the multiarch patch was added.
