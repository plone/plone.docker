# Plone 4.1 legacy image

Plone 4.1.6 on Zope 2.13.15 / Python 2.6.9. Buildout era.

**Not for production.** This stack has known, unpatched vulnerabilities. The
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 4.1/Dockerfile -t plone-legacy:4.1.6 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone41-data:/data plone-legacy:4.1.6
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

- **[V 2026-08-20]** 4.1.6 is **both** the final 4.1.x release and the last
  UnifiedInstaller, so this row needs no compromise — unlike 4.0 and 4.2.
- **[V 2026-08-20]** **lxml appears here, and it is not the hot spot we were
  warned about.** The buildout builds lxml 2.2.8 from source and failed with

  ```
  src/lxml/etree_defs.h:9: fatal error: libxml/xmlversion.h: No such file
  ERROR: xslt-config: not found
  ```

  That is simply missing `libxml2-dev` / `libxslt1-dev`, now installed in the
  build stage. The recorded hot spot — "old lxml does not compile against
  libxml2 >= 2.12" — does **not** bite: bookworm ships libxml2 **2.9.14**, so no
  static libxml2 build (`z3c.recipe.staticlxml`) is needed. Revisit if the base
  image ever moves to trixie.
- **[V 2026-08-20]** Zope is 2.13.15, from the installer’s own pins.
- **[V 2026-08-20]** Zero product import/install errors; a site is created and
  renders ~19.7 kB. Passes twice.

## Smoke test (CI gate)

```sh
make test-4.1
SMOKE_CREATE_SITE=1 make test-4.1
```
