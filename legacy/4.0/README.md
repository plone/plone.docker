# Plone 4.0 legacy image

Plone 4.0.9 on Zope 2.12.19 / Python 2.6.9. Buildout era.

**Not for production.** This stack has known, unpatched vulnerabilities. The
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 4.0/Dockerfile -t plone-legacy:4.0.9 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone40-data:/data plone-legacy:4.0.9
```

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |

## How it is built

From the Launchpad **UnifiedInstaller**, whose
`packages/buildout-cache.tar.bz2` is a complete offline cache of every egg and
distribution including Zope itself. Buildout runs fully offline, so the old
toolchain never has to negotiate modern TLS. See
`shared/build-plone-buildout.sh`.

## Validated facts / hypotheses

- **[V 2026-08-20]** **4.0.9, not 4.0.10.** 4.0.10 is the final 4.0.x release and
  its complete egg set is published at `dist.plone.org/release/4.0.10/`, but
  Launchpad has **no UnifiedInstaller past 4.0.9** — and the installer is what
  carries the offline `buildout-cache`. Building 4.0.10 would mean hand-writing a
  buildout against the release directory; that is a separate piece of work.
- **[V 2026-08-20]** Zope is **2.12.19**, read from the installer’s own
  `zope_versions.cfg` after an initial guess of 2.12.20 (taken from the 4.0.10
  release dir) proved wrong.
- **[V 2026-08-20]** **Plone 4 packages Zope as an egg** (`Zope2-2.12.19.zip` in
  `downloads/dist/`), not the `configure && make` tarball used through 3.x. It is
  built during buildout, which is the main argument for driving the vendor
  installer rather than assembling an instance by hand.
- **[V 2026-08-20]** Python **2.6.9**. The cached eggs are all `-py2.6.egg`, so
  the interpreter minor version is not a free choice. `build-python2.sh` needed
  capability detection to handle it — see the 4.2 README.
- **[V 2026-08-20]** 4.0.9 does **not** pull lxml, which is why it builds without
  `libxml2-dev`. 4.1 and 4.2 do.
- **[V 2026-08-20]** Zero product import/install errors; a site is created and
  renders ~19 kB carrying the Plone `generator` meta tag. Passes twice.

## Smoke test (CI gate)

```sh
make test-4.0
SMOKE_CREATE_SITE=1 make test-4.0
```
