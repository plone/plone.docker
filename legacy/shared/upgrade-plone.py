# -*- coding: utf-8 -*-
"""Run Plone's own migration against the database this instance opens.

Driven by the `upgrade` command of both entrypoints, as a ONE-SHOT container
over a stopped database:

    docker run --rm -v <data>:/data plone-legacy:4.0 upgrade

It cannot run against a live instance: FileStorage takes an exclusive lock, so
a `docker exec` into a running container dies with ``zc.lockfile.LockError``,
which reads like corruption rather than like "stop the server first".

Nothing here is version-branched. Everything that differs across the eleven
versions is DISCOVERED from the objects actually present, because none of these
signatures is stable across the series.
"""

import inspect
import os
import re
import sys

# Printed on the last line and nowhere else. `zopectl run` / `instance run` do
# not reliably propagate a script's exit status — the repo learned this with
# reset-admin-password.py, whose SENTINEL exists for the same reason — so the
# entrypoint trusts this string and not $?. A silent failure that looked like
# success would hand back a database that was never migrated.
SENTINEL = "UPGRADE-OK"

SITE_ID = os.environ.get("SITE_ID", "Plone")

# `app` is bound by `zopectl run` / `instance run`. Falling back to Zope2.app()
# keeps the script usable from a plain interpreter (and from `zopectl debug`).
# The lookup is a dict access, so the miss is a KeyError and NOT a NameError.
try:
    app = globals()["app"]
except KeyError:
    import Zope2

    app = Zope2.app()


def commit():
    """Commit the current transaction across the whole Zope range.

    Zope 2.8 introduced the ``transaction`` package; 2.7 — which Plone 1.0 and
    2.0 run on — has only the ``get_transaction`` builtin.
    """
    try:
        import transaction
    except ImportError:
        get_transaction().commit()  # noqa: F821  (Zope 2.7 builtin)
    else:
        transaction.commit()


def abort():
    """Abort the current transaction across the whole Zope range.

    The counterpart of :func:`commit`, used on any failure path so a partial
    migration cannot reach the storage.
    """
    try:
        import transaction
    except ImportError:
        get_transaction().abort()  # noqa: F821  (Zope 2.7 builtin)
    else:
        transaction.abort()


def make_request(app):
    """Rebind the application root to a real request.

    ``zopectl run`` binds a bare ``app`` with no REQUEST at all, and migration
    steps reach for one — directly, and through the ``@@`` views and portlet
    machinery they call. ``Testing.makerequest`` is the portable way to supply
    one: [V 2026-08-21] it exists in every Zope of the matrix, 2.7 through
    2.13.

    :param app: the bare Zope application root
    :returns: the same root, wrapped in a request
    """
    from Testing.makerequest import makerequest

    return makerequest(app)


def become_manager():
    """Run the migration as an unrestricted user.

    Upgrade steps reindex, rewrite tools and touch protected attributes across
    the whole site. Unauthenticated, the run dies partway through on a
    permission error, which reads like a broken database rather than like a
    missing login. ``AccessControl.SpecialUsers.system`` is the user Zope
    itself uses for that, and [V 2026-08-21] it is importable in every version
    of the matrix.
    """
    from AccessControl.SecurityManagement import newSecurityManager
    from AccessControl.SpecialUsers import system

    newSecurityManager(None, system)


def enter_site(site):
    """Make ``site`` the current local component site, if the era has any.

    This is the step whose absence breaks a 3.x -> 4.x migration, and the
    failure names nothing useful:

        ComponentLookupError: (<InterfaceClass
        plone.app.viewletmanager.interfaces.IViewletSettingsStorage>, '')

    A Plone site from 3.0 on keeps its own component registry, and utilities
    registered there are invisible until the site is entered. Browsing to the
    site does this for you; a script has to do it by hand.

    The hook moved twice, so it is DISCOVERED rather than branched on a version
    — [V 2026-08-21] across the matrix: ``zope.component.hooks`` on 4.2,
    ``zope.site.hooks`` from 4.0, ``zope.app.component.hooks`` from 2.5, and
    nothing at all on 1.0 and 2.0, which predate the component architecture
    entirely.

    :param site: the Plone site object
    :returns: True if a site was entered
    """
    set_site = None
    for module_name in (
        "zope.component.hooks",
        "zope.site.hooks",
        "zope.app.component.hooks",
    ):
        try:
            module = __import__(module_name, globals(), locals(), ["setSite"])
        except ImportError:
            continue
        set_site = module.setSite
        break

    if set_site is None:
        return False

    # 2.5 has the hook but its portal is not a local site: entering one that
    # cannot answer getSiteManager() raises, and there is nothing to gain.
    if not hasattr(site, "getSiteManager"):
        return False

    set_site(site)
    return True


def get_site(app, site_id):
    """Return the Plone site object, or fail with a message worth reading.

    :param app: the Zope application root
    :param site_id: id of the Plone site to migrate
    :returns: the Plone site object
    :raises RuntimeError: if there is no such object, or it is not a Plone site
    """
    try:
        site = app[site_id]
    except KeyError:
        available = [str(k) for k in app.objectIds()]
        raise RuntimeError(
            "no object with id %r at the Zope root; found: %s "
            "(set SITE_ID to pick another)"
            % (site_id, ", ".join(available) or "nothing")
        )
    if not hasattr(site, "portal_migration"):
        raise RuntimeError(
            "%r exists but has no portal_migration — it is not a Plone site"
            % (site_id,)
        )
    return site


def upgrade_accepts_swallow_errors(migration_tool):
    """Report whether ``upgrade()`` takes a ``swallow_errors`` argument.

    Plone 1.0.6 declares ``upgrade(self, REQUEST=None, dry_run=None)`` and
    swallows every step error unconditionally — a bare ``except:`` that appends
    to a report string and stops the loop. From Plone 2.0 on the signature
    gained ``swallow_errors=1``, which can be turned off so the real traceback
    reaches the caller.

    Discovered rather than branched on a version, and inspected rather than
    probed with a ``try/except TypeError``: a TypeError raised from *inside*
    the migration would otherwise be misread as a signature mismatch and the
    whole upgrade run a second time.

    :param migration_tool: the site's ``portal_migration`` tool
    :returns: True if the argument is accepted
    """
    try:
        args = inspect.getargspec(migration_tool.upgrade)[0]
    except TypeError:
        return False
    return "swallow_errors" in args


def readable(report):
    """Return a migration report fit for a container log.

    Every era before 4.0 returns the report as an HTML fragment — headings,
    paragraphs and all — so printing it raw buries the two lines that matter
    under a DOCTYPE and a wall of tags.

    Only ever used for DISPLAY. ``failed()`` reads the raw string, so a marker
    that happens to sit inside markup can never be lost to this.

    :param report: the string ``upgrade()`` returns
    :returns: the same report as plain text
    """
    if not report:
        return ""
    # Dropped whole, tag and contents alike: stripping only the tags would
    # leave a page's worth of CSS in the log, which is exactly what the old
    # eras return — their report comes wrapped in the migration tool's own
    # rendered page.
    text = re.sub(r"(?is)<(style|script)\b[^>]*>.*?</\1>", "", report)
    text = re.sub(r"(?i)<br\s*/?>", "\n", text)
    text = re.sub(r"(?i)</(p|div|li|tr|h[1-6]|pre)>", "\n", text)
    text = re.sub(r"<[^>]*>", "", text)
    text = text.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    text = text.replace("&quot;", '"').replace("&nbsp;", " ")
    lines = []
    for line in text.split("\n"):
        line = line.strip()
        if line:
            lines.append(line)
    return "\n".join(lines)


def failed(report):
    """Report whether a migration report describes a failure.

    Needed even when ``swallow_errors`` is off, because Plone 1.0.6 has no such
    switch, and because every era logs a failed upgrade path as text and then
    returns normally. The markers are the ones the tools themselves emit:
    ``Migration has failed`` (all eras) and ``Upgrade aborted`` (1.0.6).

    :param report: the string ``upgrade()`` returns
    :returns: True if the report carries a failure marker
    """
    if not report:
        return False
    return "Migration has failed" in report or "Upgrade aborted" in report


def main(app):
    """Migrate the site named by ``SITE_ID`` and commit the result.

    :param app: the Zope application root
    :returns: 0 on success
    :raises RuntimeError: if the upgrade path does not reach the current
        version, or the migration reports a failure
    """
    # Order matters: the request has to be in place before anything acquires
    # from it, and the site has to be entered before the tool is used, not
    # merely before upgrade() is called — getInstanceVersion() already goes
    # through the component registry on the 4.x line.
    app = make_request(app)
    become_manager()

    site = get_site(app, SITE_ID)
    if enter_site(site):
        print("entered the local site %r" % (SITE_ID,))

    migration_tool = site.portal_migration

    before = migration_tool.getInstanceVersion()
    target = migration_tool.getFileSystemVersion()

    if not migration_tool.needUpgrading():
        print("already at %s; nothing to do" % before)
        return 0

    print("upgrading %s: %s -> %s" % (SITE_ID, before, target))

    if upgrade_accepts_swallow_errors(migration_tool):
        report = migration_tool.upgrade(swallow_errors=0)
    else:
        # Plone 1.0.6: errors are swallowed whatever we do, so the report and
        # the post-check below are the only evidence available.
        report = migration_tool.upgrade()

    if report:
        print(readable(report))

    # Three independent checks, because each on its own has a blind spot: with
    # swallow_errors off a raised step never reaches here at all, `failed()`
    # catches the eras that only log, and needUpgrading() catches an upgrade
    # path that simply ran out before reaching the filesystem version.
    if failed(report):
        raise RuntimeError("migration reported a failure; see the report above")

    if migration_tool.needUpgrading():
        raise RuntimeError(
            "the upgrade path did NOT reach the current version: still at %s, "
            "expected %s" % (migration_tool.getInstanceVersion(), target)
        )

    # [V 2026-08-21] MigrationTool.upgrade() never commits — the only
    # transaction calls anywhere in it are abort(). Neither does `zopectl run`
    # on exit. Without this the whole migration is computed and then discarded,
    # and the next start finds the database exactly as it was.
    commit()

    print(
        "upgraded %s: %s -> %s" % (SITE_ID, before, migration_tool.getInstanceVersion())
    )
    return 0


try:
    status = main(app)
except Exception:
    abort()
    import traceback

    traceback.print_exc()
    status = 1
else:
    # Only ever printed on the success path, and only after the commit.
    print(SENTINEL)

sys.exit(status)
