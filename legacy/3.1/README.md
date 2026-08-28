# Plone 3.1 legacy image

Plone 3.1.7 on Zope 2.10.6 / Python 2.4.6. **The first buildout-era image.**

**Not for production.** Zope 2.10 has known, unpatched vulnerabilities. This
image exists for content extraction, migration rehearsal, and historical
inspection.

## Why this is a buildout image, though the matrix said "tarball"

There is no full `Plone-3.1.x.tar.gz`. Anywhere.

- `dist.plone.org` carries only `PloneBase-3.1.x` — the **stripped core**, with
  no dependency products. The repo convention is to always use a full bundle.
- `dist.plone.org/release/`, which does hold complete egg sets, **starts at 3.2**.
- The last full product bundle published for any series is `Plone-3.0.5.tar.gz`.

The only complete published source for 3.1.7 is the **UnifiedInstaller** on
Launchpad, and it is buildout-based. So 3.1 is where the tarball template ends,
one release earlier than the matrix predicted.

That turns out to be good news for determinism: the installer ships
`packages/buildout-cache.tar.bz2`, a **complete offline cache** — every
old-style product tarball, `Zope-2.10.6-final.tgz`, and pre-built py2.4 eggs
including `zc.buildout` and every `plone.recipe.*`. The build never touches the
network after the fetch stage, which matters because this toolchain cannot
negotiate modern TLS. This is the offline egg cache decision D5 anticipated —
already solved upstream, not something we had to invent.

The install sequence in `shared/build-plone-buildout.sh` is taken from the
installer's own `helper_scripts/standalone-mode.sh`, not improvised: copy
`standalone_template`, substitute `__TARGET__` / `__PASSWORD__`, strip the
root-only `chown` commands, then run `bin/buildout -No` (`-N` don't seek newer,
`-o` **offline**).

## Usage

```sh
docker build -f 3.1/Dockerfile -t plone-legacy:3.1.7 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone31-data:/data plone-legacy:3.1.7
```

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG |
| ElementTree | from the buildout cache (an egg, not a separate install) |

## Validated facts / hypotheses

- **[V 2026-08-20]** The offline buildout works: `bin/buildout -No` completes,
  compiles Zope 2.10.6 from the cached tarball, and produces `bin/instance`,
  `parts/plone` and `var` — the three things the vendor installer itself checks.
- **[V 2026-08-20]** The shipped `bin/buildout` is **regenerated, not patched**.
  It hardcodes `#!__TARGET__/Python-2.4/bin/python` and references
  `setuptools-0.6c8-py2.4.egg`, but the cache actually ships **0.6c9** — that
  path does not exist, and `install.sh` only gets away with it because it
  installs setuptools into the interpreter separately. The script discovers the
  real egg names from the cache instead, which is self-correcting across
  versions.
- **[V 2026-08-20]** A buildout instance needs a **different entrypoint**:
  `zope.conf` and `inituser` live under `parts/instance/` (both *generated* by
  `plone.recipe.zope2instance`), and the runner is `bin/instance fg`, not
  `bin/runzope`. Hence `shared/docker-entrypoint-buildout.sh`.
- **[V 2026-08-20]** The generated `inituser` is **not plaintext** — it is
  `admin:{SHA}<base64>`. The entrypoint therefore reuses Zope's own
  `parts/zope2/utilities/zpasswd.py` rather than reimplementing the hash.
- **[V 2026-08-20]** `var/filestorage` and `var/log` are **symlinked** to
  `/data/...` at build time rather than rewriting `zope.conf`. `zope.conf` is
  generated and any later buildout run would overwrite an in-place edit; the
  symlink survives. Same approach as the official `plone/plone.docker` images.
- **[V 2026-08-20]** The `[unifiedinstaller]` part is deliberately left in.
  Removing it from `parts` does **not** stop it — buildout still reports
  "Installing unifiedinstaller" and generates `bin/plonectl`, because the
  section is reached through another part's references. Keeping a sed that looks
  effective and is not would be worse; `bin/plonectl` is simply unused here.
- **[V 2026-08-20]** **A gate was silently vacuous and is now fixed.** The
  smoke test's product-load check grepped `/data/log/event.log`, which is the
  *tarball-era* name; buildout instances write `instance.log`. 3.1's first
  "OK: no product import/install errors" was therefore checking a file that did
  not exist. `shared/smoke-test.sh` now globs `/data/log/*.log` and **fails if
  it finds no log at all**, so a future rename breaks the build instead of
  quietly disabling the gate.
- **[V 2026-08-20]** With the check actually reading
  `instance.log` + `instance-Z2.log`: zero product import/install errors, and a
  Plone 3.1 site can be created and rendered (~20 kB with the Plone `generator`
  meta tag). Passes twice consecutively.

## Smoke test (CI gate)

```sh
make test-3.1                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-3.1  # also creates a Plone site and checks its markup
```
