# Plone 1.0 legacy image

Plone 1.0.6 on Zope 2.7.8 / Python 2.3.7, with CMF 1.3.3. Tarball-era template
(no buildout). The oldest Plone in the matrix, and **the only image that
patches upstream source** — see "The two patches" below.

**Not for production.** Zope 2.7 has known, unpatched vulnerabilities. This
image exists for content extraction, migration rehearsal, and historical
inspection.

## Usage

```sh
docker build -f 1.0/Dockerfile -t plone-legacy:1.0.6 .
docker run -d -p 8080:8080 -e ADMIN_PASSWORD=secret \
    -v plone10-data:/data plone-legacy:1.0.6
```

Creating a site through the ZMI: **pick a customisation policy.** The `Add
Plone Site` form has a `Customization Policy` dropdown that defaults to
nothing, and a site created with it empty is broken (see below). Choose
`Default Plone`.

| | |
|---|---|
| Port | 8080 (`ZOPE_HTTP_PORT` to change) |
| FTP | 8021, **not** `EXPOSE`d — publish with `-p 8021:8021` if wanted |
| Volume | `/data` (`filestorage/Data.fs`, `log/`) |
| User | `plone` (uid 500) |
| Env | `ADMIN_USER`, `ADMIN_PASSWORD` (first run only) |
| PIL | 1.1.6, with JPEG + PNG (no freetype/`_imagingft`) |

Runtime shape, entrypoint and FTP behaviour are identical to
[2.0](../2.0/README.md), which shares the same Zope.

## Where the code comes from

Unlike every 2.x release, **no single 1.0.6 artifact carries a working Plone**.
The image assembles it from three:

| Source | Supplies |
|---|---|
| `dist.plone.org/archive/Plone-1.0.6.tar.gz` | `CMFPlone` — and nothing else |
| `dist.plone.org/archive/CMFPlone1.0.5.tar.gz` | `DCWorkflow` 0.5+, `Formulator` 1.4.1 |
| `old.zope.dev/.../CMF-1.3.3.tar.gz` | `CMFCore`, `CMFDefault`, `CMFTopic`, `CMFCalendar` |

`CMFPlone/INSTALL.txt` asks for exactly three Plone products — CMFPlone,
DCWorkflow and Formulator — plus CMF 1.3 or later. Only the first is in the
1.0.6 tarball, and **neither DCWorkflow nor Formulator is separately
downloadable anywhere**: `old.zope.dev/Products/DCWorkflow/` and
`.../Formulator/` both 404. The 1.0.5 release bundle
(`CMFPlone-1.0.5/{CMFPlone,DCWorkflow,Formulator,i18n}`) is the only surviving
source, so 1.0.6 supplies CMFPlone and 1.0.5 supplies its two companions.

## Validated facts / hypotheses

- **[V 2026-08-20]** **1.0.6 is the only downloadable 1.0.x.**
  `Plone-1.0.tar.gz`, `Plone-1.0.1.tar.gz` and `Plone-1.0.2.tar.gz` are all
  listed in the `dist.plone.org/archive/` index and all **404**, serving a
  3,056-byte HTML error page — which `tar` reports as "Unrecognized archive
  format" rather than as a failed download. 1.0.3, 1.0.4 and 1.0.5 published no
  `.tar.gz` at all under that name (only RPM, `.exe` and MacOS `.pkg`).
- **[V 2026-08-20]** **Zope 2.6.4 was not needed, and would have been much more
  expensive.** Plone 1.0.6 is written for Zope 2.6.x, which
  `Zope-2.6.4-src/README.txt` states requires **Python 2.1** ("This release
  requires Python 2.1."). Zope 2.6 also has no `./configure` — it builds via
  `wo_pcgi.py`, and creates instances with `inst/make_instance.py` rather than
  `mkzopeinstance.py` — so it would have meant a new interpreter *and* a new
  template. Running on Zope 2.7.8 / Python 2.3.7 instead reuses 2.0's Dockerfile
  almost verbatim, at a cost of two patched files.
- **[V 2026-08-20]** **CMFPlone 1.0.6 has only two optional dependencies, and
  both are genuinely optional.** Its complete set of `Products.*` imports is
  CMFCore, CMFDefault, CMFCalendar, DCWorkflow, Formulator, ExternalMethod,
  SiteAccess, PageTemplates, PythonScripts, Localizer and CMFEventService. The
  last two sit behind `try/except` — `PloneInitialize.py:8` and
  `WorkflowTool.py:15` — and the four before them ship with Zope. So nothing
  beyond the table above is required, and **zero products fail to import or
  install**.
- **[V 2026-08-20]** **PIL is not imported at all by 1.0.6**, as in 2.0.5 (where
  the single use site is guarded) and unlike 2.1.4 and 2.5.4. Bundled anyway by
  the same decision, so scaling works and every tarball-era image has the same
  shape.
- **[V 2026-08-20]** The site factory matches 2.0 and 2.1: `/manage_main` links
  `CMFPlone/addSite`, whose form posts to `manage_addSite`. The smoke test
  discovers this rather than assuming it.
- **[V 2026-08-20]** **A site created without `custom_policy` is accepted and
  then broken.** The ZMI factory defaults the argument to empty —
  `CMFPlone/Portal.py:289  custom_policy='',` — while
  `CustomizationPolicy.py:50` is what calls
  `portal._setProperty('left_slots', ...)`. So the POST returns its usual 302
  and the site root then 500s on every render:

  ```
  Module None, line 11, in prepare_slots
  AttributeError: left_slots
  ```

  Plone 2.0.5 and 2.1.4 take the same argument but default it to
  `'Default Plone'`, which is why this never surfaced before 1.0. The smoke
  test now posts the policy whenever the add-form offers the control, rather
  than branching on a version number.
- **[V 2026-08-20]** **Plone 1.0.6 emits no `generator` meta tag** — the marker
  every version from 2.0 up carries, and the one the smoke test asserted. Its
  only `<meta>` is `imagetoolbar`. The site root does carry
  `plone_javascripts`, an `@import` of `plone.css`, `<title>… - Welcome to
  Plone</title>` and 68 occurrences of the word Plone, so the gate now accepts
  those skin markers as a documented fallback and prints which marker matched.
- **[V 2026-08-20]** A Plone 1.0.6 site can be created and rendered: the site
  root serves **21,167 bytes** of real Plone markup, and the image passes
  `SMOKE_CREATE_SITE=1` **twice consecutively**.
- **[V 2026-08-20]** Beyond the site root, `login_form`, `folder_contents`,
  `search`, `personalize_form`, `join_form`, `news`, `plone.css` and
  `portal_types/manage_main` all answer 200. `contact-info` 404s; it is a
  Plone 2 page and not part of 1.0.

## The two patches

Both live in [`patches/`](patches/), are applied with `patch -p1 --forward
--batch` in the build stage, and fail the build if rejected. Both exist for the
same reason — a Zope 2.6-era Plone running on Zope 2.7 — and **neither is a bug
in Plone 1.0.6**: each is correct against the Zope it was written for.

### `0001-isExpired-datetime-syntaxerror.patch`

`CMFPlone/skins/plone_scripts/isExpired.py` guards its date parse with
`except IndexError`. CMF returns the literal string `'None'` from
`ExpirationDate()` when no expiry is set, and the two DateTime
implementations disagree about what that raises. Verified by running both
modules side by side under the image's own Python 2.3.7:

```
Zope 2.6.4  DateTime('None') -> exceptions.IndexError          <- what Plone catches
Zope 2.7.8  DateTime('None') -> DateTime.DateTime.SyntaxError  <- escapes
```

So on 2.7 the exception escapes and **every page render 500s**:

```
Module None, line 8, in isExpired
Module DateTime.DateTime, line 513, in __init__
SyntaxError: Unable to parse ('None',), {}
```

The patch widens the handler. Upstream intent is unchanged: a date that will
not parse has not expired.

### `0002-login_form-tal-nesting.patch`

`CMFPlone/skins/plone_forms/login_form.pt` builds its cookie warning with a
`document.writeln('<p><div …><font color="red">…</font>…')` inside a `<script>`
block. Zope 2.6's parser tolerated that markup; Zope 2.7's `HTMLTALParser`
reads it as real tags and the template fails to compile, so `/login_form` is a
hard 500:

```
RuntimeError: FS Page Template login_form has errors: Compilation failed.
TAL.HTMLTALParser.NestingError: Open tags <html>, <body>, <div>, <script>
do not match close tag </font>, at line 64, column 132
```

The patch splits the close tags across a string concatenation so the parser
cannot see them, leaving the emitted JavaScript identical.

**This is the whole template risk, and it was measured rather than estimated.**
Running Zope 2.7.8's `HTMLTALParser` over every template in the product tree
gave **189 templates, 1 failing** before the patch and **189 templates, 0
failing** after it.

## Smoke test (CI gate)

```sh
make test-1.0                      # HTTP + auth + every product loads
SMOKE_CREATE_SITE=1 make test-1.0  # also creates a Plone site and checks its markup
```
