# The `-demo` variants

Every image in the matrix has a `-demo` twin that **already has a Plone site**,
created at the id `Plone`. Start one and browse straight to
`http://localhost:8080/Plone` — no ZMI, no add-form, no waiting for a site to
be built.

```sh
make demo-2.1                       # builds plone-legacy:2.1.4-demo (and :2.1-demo)
docker run -d -p 8080:8080 plone-legacy:2.1-demo
open http://localhost:8080/Plone
```

| | |
|---|---|
| Site id | `Plone` (`--build-arg DEMO_SITE_ID=` to change) |
| Admin | `admin` / `admin` (`--build-arg DEMO_ADMIN_PASSWORD=` to change) |
| Everything else | identical to the base image — same Zope, Python, products, entrypoint |

`make demos` builds every series listed in the Makefile's `SERIES`;
`make test-demos` smoke-tests them.

## Credentials

`ADMIN_USER` and `ADMIN_PASSWORD` work at **run** time, exactly as they do on a
base image:

```sh
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=something-else plone-legacy:2.1-demo
```

They cannot get there by Zope's usual route. `inituser` is consulted only while
a database is being *created*, and a demo image ships one already made — so the
entrypoint applies them directly to the seeded database, through
[`shared/reset-admin-password.py`](../shared/reset-admin-password.py), before
Zope starts serving. Three cases:

| You set | What happens |
|---|---|
| nothing | the build-time credentials stay (`admin` / `admin` by default) |
| `ADMIN_PASSWORD` | that user is re-keyed; the build-time password stops working |
| `ADMIN_USER` **and** `ADMIN_PASSWORD` | the new user is created as a Manager and **the build-time user is removed** |

That last row matters: leaving the build-time account in place would keep a
password that is *published in this README* working on an image whose operator
believes they replaced it. If the account cannot be deleted, it is re-keyed to
the supplied password instead — untidy, but it closes the hole either way, and
the two outcomes are logged differently.

The defaults can also be changed at build time:

```sh
docker build -f demo/Dockerfile \
    --build-arg BASE_IMAGE=plone-legacy:2.1.4 \
    --build-arg DEMO_ADMIN_PASSWORD=something-else \
    -t plone-legacy:2.1.4-demo .
```

These are demo images for a throwaway stack, and the default is deliberately
the obvious one. **Do not put them anywhere reachable.**

## How it works

One `Dockerfile` serves all eleven versions, taking the base image as
`BASE_IMAGE`:

1. **Stage `seed`** — installs `curl`, then runs
   [`shared/seed-demo-site.sh`](../shared/seed-demo-site.sh), which starts the
   image's own entrypoint, waits for HTTP, creates the site through
   [`shared/create-plone-site.sh`](../shared/create-plone-site.sh), shuts Zope
   down cleanly, and copies the resulting database to `/app/seed/Data.fs`.
2. **Stage 2** — `FROM ${BASE_IMAGE}` again, plus that one file. The stage that
   needed `curl` is discarded, so the published demo image carries no tooling
   the base image doesn't.

Three details are load-bearing:

- **The database is baked at `/app/seed`, never at `/data`.** `/data` is a
  `VOLUME` in the base image, and anything a build layer writes beneath a
  volume mount point is discarded when the layer is committed. The entrypoint
  copies the seed into `/data/filestorage/` on first start instead — and skips
  it when `/data` already holds a database, so mounting a real site over a demo
  image still works exactly as before.
- **The site is created through the same script the CI gate uses.** If the
  demo images were seeded by their own private code path, `make test-demo-*`
  would be testing that path rather than the one `make test-*` exercises.
- **The site is created by running the image's own entrypoint**, as the `plone`
  user, rather than by a build-only configuration — so the database is produced
  by the same startup path that will later open it.

## Validated facts / hypotheses

- **[V 2026-08-20]** **Zope applies `inituser` whenever the file exists — it
  does not first check whether the database already has users.** This is the
  one real trap in seeding, and it fails silently in a way that looks like
  anything but its cause. A `-demo` image inherits the base image's placeholder
  `inituser` (`mkzopeinstance --user admin:placeholder`, stored pre-hashed as
  `admin:{SHA}/1VDU0WDSj/iJJNndsKqFfbtU1g=`). At first start Zope applied it
  *on top of* the seeded database and deleted the file, so the image came up
  with a perfectly good Plone site at `/Plone` and **no working password**:

  ```
  ROOT USERS: ['admin']
  PW: '{SHA}/1VDU0WDSj/iJJNndsKqFfbtU1g='   # sha1('placeholder'), not sha1('admin')
  AUTH admin/admin: None
  ```

  Both entrypoints now delete the leftover `inituser` as part of seeding. Note
  what the symptom looked like: the site rendered, so every check except
  authentication passed — which is exactly why `smoke-test.sh` asserts
  `/manage_main` authenticates before it asserts anything about content.
- **[V 2026-08-20]** **The Zope root user folder has two different shapes, and
  the classic API raises on one of them.** A freshly created instance has a
  classic `UserFolder` at the root in every version, 1.0 through 4.2 — but in a
  database where a Plone site has been added, some versions have a full
  `PluggableAuthService` there instead. On those, `acl._doChangeUser(...)` does
  not merely behave differently; it goes through PlonePAS and dies with
  `KeyError: <InterfaceClass ...plugins.IUserManagement>`, because the root's
  plugin registry has no such plugin type. `reset-admin-password.py` detects
  the shape at run time (`hasattr(acl, 'plugins')`) rather than keying off a
  version.
- **[V 2026-08-20]** **`ZODBUserManager.updateUserPassword` changed arity.**
  Newer PluggableAuthService takes `(user_id, login_name, password)`; the one
  in Plone 3.1 takes `(user_id, password)` and answers the longer call with
  `TypeError: updateUserPassword() takes exactly 3 arguments (4 given)`. The
  script tries the modern spelling and falls back.
- **[V 2026-08-20]** **`Data.fs.lock` is not a shutdown-cleanliness signal.**
  It survives an ordinary clean stop/start cycle on a base image, so warning on
  it fired on every good build. The seed script checks for `Data.fs.index`
  instead, which FileStorage writes on a clean close and not when it is killed.
- **[V 2026-08-20]** **The demo build must use a builder that can read the
  local image store.** `FROM ${BASE_IMAGE}` resolves against the daemon's
  images, and a `docker-container` builder — which
  `docker/setup-buildx-action` makes the default in CI — cannot see them and
  tries to pull instead, failing with `pull access denied, repository does not
  exist`. CI therefore passes `DEMO_BUILDER=default`; locally the variable is
  left empty, so the current builder is used. **Do not hardcode `default` in
  the Makefile** — on Docker Desktop the active context is `desktop-linux`, and
  naming a builder bound to another context fails with ``use `docker
  --context=default buildx` to switch to context "default"``. The same
  pull-access error also appears locally whenever `--platform linux/amd64` is
  omitted, because the amd64-only base image does not match the arm64 host and
  is likewise treated as absent.
