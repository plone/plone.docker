# Changelog

- Switch from `curl` to `wget`, becaue `wget` has less dependecies than `curl`
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
