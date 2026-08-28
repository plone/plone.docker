# Plone 3.2 legacy image

Plone 3.2.3 on Zope 2.10.7 / Python 2.4.6. Buildout era.

**Not for production.** Zope 2.10.7 has known, unpatched vulnerabilities. This
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 3.2/Dockerfile -t plone-legacy:3.2.3 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone32-data:/data plone-legacy:3.2.3
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

- **[V 2026-08-20]** **The installer layout changed after 3.1.** 3.1 ships a
  complete `standalone_template/`; 3.2 ships `base_skeleton/` (no buildout.cfg)
  plus `buildout_templates/standalone.cfg` to drop in. This is the same shape
  the official `plone/plone.docker` images consume for 4.3, so it is the one
  that persists. `shared/build-plone-buildout.sh` detects which it has and
  fails loudly on anything else.
- **[V 2026-08-20]** **Zope here is 2.10.7, not 2.10.8.** The version was
  corrected from a guess after reading it off the built image
  (`/app/Zope-2.10.7-final-py2.4`). The installer's cache decides this, not the
  matrix.
- **[V 2026-08-20]** **There is no `parts/plone` from 3.2 on.** Plone arrives as
  eggs, so 3.1's post-buildout assertion (copied from the vendor's own
  `standalone-mode.sh`) had to be replaced with checks on `bin/instance` and the
  generated `parts/instance/etc/zope.conf`, which are universal.
- **[V 2026-08-20]** **Zope moves out of the instance.** 3.2's template sets
  `zope-directory`, so Zope installs to `/app/Zope-<ver>-py2.4/` rather than
  `<instance>/parts/zope2/`. The entrypoint therefore *discovers*
  `utilities/zpasswd.py` instead of hardcoding 3.1's path — that hardcoded path
  was what made the first 3.2 container exit 1 with no log at all.
- **[V 2026-08-20]** Non-root handling follows the installer's own
  `helper_scripts/create_instance.py`: delete the `effective-user` options and
  strip the `chown` commands. A leftover `__PLACEHOLDER__` on a live line is now
  a build failure.
- **[V 2026-08-20]** Zero product import/install errors; a Plone 3.2 site is
  created and renders ~21 kB with the Plone `generator` meta tag. Passes twice.

## Smoke test (CI gate)

```sh
make test-3.2
SMOKE_CREATE_SITE=1 make test-3.2
```
