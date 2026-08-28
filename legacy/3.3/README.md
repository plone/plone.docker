# Plone 3.3 legacy image

Plone 3.3.6 on Zope 2.10.13 / Python 2.4.6. Buildout era.

**Not for production.** Zope 2.10.13 has known, unpatched vulnerabilities. This
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 3.3/Dockerfile -t plone-legacy:3.3.6 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone33-data:/data plone-legacy:3.3.6
```

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG |

## How it is built

Like 3.1, from the Launchpad **UnifiedInstaller**, whose
`packages/buildout-cache.tar.bz2` is a complete offline cache — every egg and
product tarball plus Zope itself. `bin/buildout -No` runs fully offline, so the
2000s-era toolchain never has to negotiate modern TLS. See
`shared/build-plone-buildout.sh`.

## Validated facts / hypotheses

- **[V 2026-08-20]** **Python 2.4.6, not 2.6.9.** The matrix predicted 2.6.9 for
  3.3, but the 3.3.6 UnifiedInstaller bundles `Python-2.4.6.tar.bz2` — so this
  image keeps the same interpreter as 3.0/3.1/3.2 and the shared
  `build-python2.sh` applies unchanged. Plone 3.3 *supports* 2.6, but 2.4.6 is
  what the vendor shipped and therefore what the cached eggs were built for
  (they are all `-py2.4.egg`).
- **[V 2026-08-20]** **The self-correcting bootstrap earned its keep.** Every
  installer's `bin/buildout` hardcodes `setuptools-0.6c8-py2.4.egg` and
  `zc.buildout-1.1.1-py2.4.egg`, but the caches actually ship:

  | Version | setuptools | zc.buildout |
  |---|---|---|
  | 3.1.7 | 0.6c9 | 1.1.1 |
  | 3.2.3 | 0.6c9 | 1.1.2 |
  | 3.3.6 | 0.6c11 | 1.4.4 |

  Regenerating that script from what is actually in the cache — rather than
  patching the vendor's stale paths — is what let one shared script cover all
  three without per-version special cases.
- **[V 2026-08-20]** Zope is 2.10.13 (`/app/Zope-2.10.13-final-py2.4`), matching
  the matrix for once.
- **[V 2026-08-20]** Zero product import/install errors; a Plone 3.3 site is
  created and renders ~21 kB with the Plone `generator` meta tag. Passes twice.

## Smoke test (CI gate)

```sh
make test-3.3
SMOKE_CREATE_SITE=1 make test-3.3
```
