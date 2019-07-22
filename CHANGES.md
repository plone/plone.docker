# Changelog

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
