# Plone 2.0 legacy image

Plone 2.0.5 on Zope 2.7.8 / Python 2.3.7. Tarball-era template (no buildout).
The oldest image in the matrix.

**Not for production.** Zope 2.7 has known, unpatched vulnerabilities. This image
exists for content extraction, migration rehearsal, and historical inspection.

## Usage

```sh
docker build -f 2.0/Dockerfile -t plone-legacy:2.0.5 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone20-data:/data plone-legacy:2.0.5
```

To mount an existing site, drop its `Data.fs` at `/data/filestorage/Data.fs`
(and add its third-party products to `/app/instance/Products` via bind mount
or a derived image).

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| FTP | 8021, **not** `EXPOSE`d — publish with `-p 8021:8021` if wanted |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG (no freetype/`_imagingft`) |

### The FTP server

Unlike 2.8 and 2.9, Zope 2.7's `mkzopeinstance` writes an **uncommented
`<ftp-server>` block** alongside the HTTP one. It is left enabled here, since
FTP is a genuinely convenient way to pull content out of an old site:

```sh
docker run -d -p 8080:8080 -p 8021:8021 -e ADMIN_PASSWORD=secret plone-legacy:2.0.5
```

## Validated facts / hypotheses

- **[V 2026-08-20]** **S1 was sufficient — the period-toolchain fallback (S3,
  `debian/eol:etch`) was NOT needed.** The prior guidance was to assume S3 from
  the start for 2.0 because Zope 2.7 carries the pre-rewrite ExtensionClass,
  the oldest C in the matrix. In the event, Python 2.3.7 *and* Zope 2.7.8 both
  built on bookworm/gcc 12 with exactly the same mitigations as 2.1 and 2.5,
  via the shared `build-python2.sh` with no 2.0-specific changes.
- **[V 2026-08-20]** **Python 2.3.7 is accepted despite not being on Zope's
  list.** Zope 2.7.8's `./configure` declares `TARGET="2.3.5"` and
  `ACCEPTABLE="2.3.4 2.3.3"`. That list is only consulted by `get_python()`,
  the `$PATH` search: `--with-python=<path>` assigns `FOUND` directly and skips
  it. The real configurator, `inst/configure.py`, gates on **pyexpat, zlib and
  large-file support** and never inspects `sys.version`. Verified by reading
  both scripts before building, then confirmed by the build.
- **[V 2026-08-20]** All three of those gates pass on 2.3.7:
  `zlib 1.2.13`, `expat 1.95.7` (bundled in `Modules/expat/`), and
  `f.seek(2147483649L)` succeeds.
- **[V 2026-08-20]** The generalised multiarch patch was **load-bearing here**.
  Python 2.3.7 writes `lib_dirs` on one line —
  `lib_dirs = self.compiler.library_dirs + ['/lib', '/usr/lib']` — where 2.4.6
  uses a multi-line list, so 2.1's original literal pattern would have matched
  zero times and failed its own `grep -c` guard. `build-python2.sh` anchors on
  `self.compiler.library_dirs + [` instead, which holds for both.
- **[V 2026-08-20]** `lib-dynload` contains no `*_failed.so`. `nismodule.c`'s
  `rpc/rpc.h` error is the documented benign one (optional module, skipped).
- **[V 2026-08-20]** Gate G2: `ExtensionClass`, `Acquisition` and
  `BTrees.OOBTree` all import from the installed Zope 2.7.8 tree.
- **[V 2026-08-20]** **Bug found and fixed in the shared entrypoint.** The
  first 2.0 container exited immediately:

  ```
  ZConfig.ConfigurationError: There was a problem starting a server of type
  "FTPServer" ... (Address already in use)
  ```

  Cause: `docker-entrypoint.sh` templated `ZOPE_HTTP_PORT` with an unscoped
  `s|address N|address $PORT|`, which rewrote **every** `address` line. Zope 2.7
  emits two server blocks, so the FTP server was pointed at 8080 as well and
  Zope died binding the port twice. Zope 2.8/2.9 emit only `<http-server>`,
  which is why this stayed latent through 2.1 and 2.5. The sed is now confined
  to the `<http-server>` block by a range address. 2.1 and 2.5 were rebuilt and
  re-tested after the fix, with unchanged results.
- **[V 2026-08-20]** With the fix, `zope.conf` keeps `address 8080` under
  `<http-server>` and `address 8021` under `<ftp-server>`, and the FTP service
  answers: `220 ... FTP server (Medusa Async V1.23 [experimental]) ready.`
- **[V 2026-08-20]** **PIL is optional in 2.0.5, unlike 2.1.4 and 2.5.4.**
  CMFPlone never imports it; the only use site is guarded —
  `Archetypes/Field.py:964` does `try: import PIL.Image / except: has_pil=None`
  ("no PIL, no scaled versions!"). It is bundled anyway by decision, so scaling
  works and all three tarball-era images have the same shape.
- **[V 2026-08-20]** Bundle layout is `Plone-2.0.5/<Product>/...`, 20 product
  directories (22 entries land in `Products/` counting the two loose text
  files). Zero products fail to import or install.
- **[V 2026-08-20]** The site factory matches 2.1, not 2.5:
  `/manage_main` links `CMFPlone/addSite`, whose form posts to
  `manage_addSite`. The smoke test discovers this rather than assuming it.
- **[V 2026-08-20]** A Plone 2.0 site can be created and rendered: the site
  root serves ~27 kB carrying the Plone `generator` meta tag — the largest of
  the three, since 2.0 inlines more of its markup.

## Smoke test (CI gate)

```sh
make test-2.0                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-2.0  # also creates a Plone site and checks its markup
```
