# Changelog

- Allow buildout to extend custom files
  [@pnicolli]
- Enable LDAP/AD support on Plone 5.1
  [@pnicolli]
- Only extend develop.cfg when needed
  [@pnicolli]
- Add LDAP/AD support
  [@eikichi18]
- Add RelStorage support
  [@pnicolli]
- Typo fix: CORS_TEMPLACE
  [@avoinea]
- Add find-links and sources part to custom buildout
  [pnicolli]
- Fixed interaction between SITE env var and a zeo setup. Fixes issue #135
  [pnicolli]
- Update docs
  [staeff]
- Add possibility to initialize Plone SITE with custom PROFILES/ADDONS on first run
  [avoinea refs #121]
- Cleanup docker-entrypoint.sh: Use `bin/instance console` to start Plone and `bin/zeo fg` for ZEO Server.
  See https://github.com/docker-library/official-images/pull/6343
  [avoinea]
- Added support for Diazo theme central resource directory - fixes issue #114
  [avoinea]
- Added libffi-dev to alpine 5.2.0 Dockerfile, build depedency was needed to successfully build BTrees package.
  [pigeonflight]
- Used PLONE_VERSION_RELEASE env variable in the 5.2.0 Dockerfiles... fixes issue #117
  [pigeonflght]
- add Plone 5.1 images
  [svx]
- add prerequisite of installing & running Docker
  [tkimnguyen]
- Update docs
  [svx]
- Switch from `curl` to `wget`, because `wget` has less dependencies than `curl` for Plone 5.
  [svx]
- Switch from `curl` to `wget`, because `wget` has less dependencies than `curl` for Plone 4.
  [svx]
- Remove `apt-clean`, not needed because of https://github.com/moby/moby/blob/e925820bfd5af066497800a02c597d6846988398/contrib/mkimage/debootstrap#L107-L130
  [svx]
- Add missing dependencies for pillow and transforms.
  [jladage]
- Add -m option to `useradd` command to correctly set the home dir.
  [jladage]
- Remove deprecated maintainer setting
  [svx]
- Adjust Label settings to follow best practices
  [svx]
- Add (`apt-mark showauto`), Jenkins shut up
  [svx]
