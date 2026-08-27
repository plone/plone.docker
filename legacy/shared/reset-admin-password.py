# -*- coding: utf-8 -*-
# Reset (or create) the Zope root admin user, from ADMIN_USER/ADMIN_PASSWORD.
#
# The encoding line above is required, not decorative: the comments here use
# non-ASCII punctuation, and Python 2.3 warns on every run without it —
# noise that lands in the log of every -demo container's first start.
#
# Run through the instance's own control script, which binds `app` for us:
#     bin/zopectl run reset-admin-password.py     (tarball era, Zope 2.7-2.10)
#     bin/instance run reset-admin-password.py    (buildout era, Zope 2.10-2.13)
#
# This is what makes ADMIN_PASSWORD work on a -demo image. Those images ship a
# database that was created at build time, and Zope's inituser mechanism only
# ever applies to a database that is being created — so without this, the
# baked-in credentials would be the only ones that ever worked.
#
# TWO ROOT USER FOLDERS, NOT ONE. [V 2026-08-20] A freshly created instance has
# a classic `UserFolder` at the root in every version of the matrix, 1.0 through
# 4.2. But once a Plone site has been added, some versions have a full
# PluggableAuthService there instead — and on those, the classic API does not
# merely behave differently, it raises:
#     acl._doChangeUser(...)
#       -> PlonePAS/pas.py userSetPassword -> plugins.listPlugins(IUserManagement)
#       -> KeyError: <InterfaceClass ...plugins.IUserManagement>
# because the root's plugin registry has no such plugin type. So the shape is
# detected at run time rather than inferred from a version number.
#
# COMPATIBILITY. This file is executed by every interpreter in the matrix,
# which starts at **Python 2.3** (Plone 1.0 and 2.0). Nothing here may use a
# conditional expression (`a if c else b`, 2.5+), `with`, decorators, or
# `except X as e` — 2.3 rejects all of them at compile time, and the failure is
# a SyntaxError at run, far from this comment.
import os
import sys

SENTINEL = "PASSWORD-RESET-OK"

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
        get_transaction().commit()
    else:
        transaction.commit()


def is_pas(acl):
    """True when the root user folder is a PluggableAuthService."""
    return hasattr(acl, "plugins")


def pas_plugins(acl):
    """Find the ZODB user- and role-manager plugins of a root PAS.

    Located by duck typing rather than by importing an interface, because the
    interface modules moved between PluggableAuthService versions while these
    method names did not.
    """
    user_mgr = None
    role_mgr = None
    for obj in acl.objectValues():
        if (
            user_mgr is None
            and hasattr(obj, "addUser")
            and hasattr(obj, "updateUserPassword")
        ):
            user_mgr = obj
        if role_mgr is None and hasattr(obj, "assignRoleToPrincipal"):
            role_mgr = obj
    return user_mgr, role_mgr


def ensure_user(acl, login, password, roles):
    """Create or re-key ``login``. Returns a short description of what it did."""
    if not is_pas(acl):
        if acl.getUser(login) is not None:
            acl._doChangeUser(login, password, roles, [])
            return "reset password for existing user"
        acl._doAddUser(login, password, roles, [])
        return "created user"

    user_mgr, role_mgr = pas_plugins(acl)
    if user_mgr is None:
        raise RuntimeError("root PAS has no ZODB user manager plugin")

    user_id = None
    try:
        user_id = user_mgr.getUserIdForLogin(login)
    except KeyError:
        user_id = None

    if user_id is not None:
        # [V 2026-08-20] The signature is not stable across PluggableAuthService
        # releases: newer ZODBUserManagers take (user_id, login_name, password),
        # the one shipped with Plone 3.1 takes (user_id, password) and answers
        # the longer call with
        #   TypeError: updateUserPassword() takes exactly 3 arguments (4 given)
        # Try the modern spelling first and fall back, rather than keying off a
        # version number.
        try:
            user_mgr.updateUserPassword(user_id, login, password)
        except TypeError:
            user_mgr.updateUserPassword(user_id, password)
        return "reset password for existing user"

    user_mgr.addUser(login, login, password)
    if role_mgr is not None:
        for role in roles:
            role_mgr.assignRoleToPrincipal(role, login)
    return "created user"


def remove_user(acl, login):
    """Delete ``login``. Raises if the folder offers no way to do it."""
    if not is_pas(acl):
        acl._doDelUsers([login])
        return
    user_mgr, role_mgr = pas_plugins(acl)
    if user_mgr is None:
        raise RuntimeError("root PAS has no ZODB user manager plugin")
    user_mgr.removeUser(user_mgr.getUserIdForLogin(login))


def existing_roles(acl, login):
    """Roles already held by ``login``, minus the implicit one.

    'Authenticated' is granted at request time and must not be stored on the
    user, or it shows up as a real role in the ZMI.
    """
    user = acl.getUser(login)
    roles = []
    if user is not None:
        for role in user.getRoles():
            if role != "Authenticated":
                roles.append(role)
    return roles


def main():
    user = os.environ.get("ADMIN_USER") or "admin"
    password = os.environ.get("ADMIN_PASSWORD")
    if not password:
        print("no ADMIN_PASSWORD in the environment; leaving credentials alone")
        print(SENTINEL)
        return 0

    acl = app.acl_users
    roles = existing_roles(acl, user) or ["Manager"]

    action = ensure_user(acl, user, password, roles)

    # Setting ADMIN_USER/ADMIN_PASSWORD means "these are the credentials for
    # this container", so the build-time user must not survive alongside them.
    # Leaving it would keep a *published, documented* password (admin/admin by
    # default) working on an image whose operator believes they replaced it.
    # DEMO_ADMIN_USER is stamped into the demo image by demo/Dockerfile; when
    # it is absent this script is not running against a demo image and there is
    # nothing to clean up.
    baked = os.environ.get("DEMO_ADMIN_USER")
    if baked and baked != user and acl.getUser(baked) is not None:
        try:
            remove_user(acl, baked)
            print("removed the build-time user %r, superseded by %r" % (baked, user))
        except Exception, exc:
            # Never leave the documented default password working. If the user
            # cannot be removed, re-key it to the supplied password instead —
            # untidy, but it closes the hole.
            ensure_user(acl, baked, password, existing_roles(acl, baked) or ["Manager"])
            print(
                "could not remove the build-time user %r (%s: %s); re-keyed "
                "it to the supplied password instead"
                % (baked, exc.__class__.__name__, exc)
            )

    commit()

    # Prove it rather than assume it: re-authenticate against the stored hash.
    if acl.authenticate(user, password, None) is None:
        print("FAILED: %s %r, but it does not authenticate" % (action, user))
        return 1

    print("%s %r with roles %s" % (action, user, roles))
    print(SENTINEL)
    return 0


sys.exit(main())
