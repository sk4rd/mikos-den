# Architecture

The goal behind the layout: adding or removing a feature should mean touching one
file. The rest of this page is what follows from that.

## One feature, one file

An aspect holds everything a feature needs, whichever level it applies to.
`modules/features/ghostty.nix` sets a system-wide session variable and installs my
user's package and config, side by side. I don't want a feature split across
separate system and home trees, where removing it means finding every piece.

Every `.nix` file under `modules/` is loaded automatically, so there are no import
lists to maintain.

## Hosts are lists

A host file says what a machine is by listing aspects, and keeps only what is true
of that machine alone, such as hardware and disks. Three things keep those lists short:

- **Defaults declare themselves.** An aspect every host needs adds itself through
  `den.schema.host.includes` in its own file, so a new host gets it automatically.
- **Per-user includes.** `provides.miko` lets a host add something for my user on
  that machine only, like dictation on the workstation.
- **Typed settings.** An aspect declares options and a host fills them in under
  `settings`, so a feature can be shared while its values differ per machine.

## Services announce themselves

A NAS service is the one feature that seems to need several places: a reverse-proxy
route, a health check, a ZFS dataset. Instead, the service's aspect declares all
three as den quirks (`modules/den.nix`), and collector aspects gather them:
`service-names` and `ddns` read the routes, `status` the health checks, `nas-storage`
the datasets. See `modules/features/jellyfin.nix` for a small example.

Routes are private by default. A service stays LAN and VPN only unless it sets
`public = true`, so forgetting the flag leaves a service private.

## Plain files stay plain

Config that is just a file lives in `dots/` in its own format, so normal tooling and
the app's own docs still apply. A module installs it. Anything that depends on Nix
values gets generated instead, like the Neovim palette built in
`modules/features/neovim.nix`.

## One theme

`lib/theme/oxocarbon.nix` holds the raw colours, and `lib/theme/default.nix` turns
them into roles like `accent` and `error`. Apps read those roles from `config.theme`,
so they can't drift apart and a palette change reaches everything at once. Files
generated entirely from the theme live in `lib/theme/render/`.
