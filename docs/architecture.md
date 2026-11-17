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

## One theme per host

Each theme is one file in `lib/theme/themes/`: a standard
[Base24](https://github.com/tinted-theming/base24) palette (`base00` to `base17`),
with optional `overrides` for any role and optional `fonts`. `lib/theme/roles.nix`
turns any such palette into roles like `accent`, `error` and `syntax.keyword`, then
applies the overrides. Apps read only roles, so none of them knows which theme is
active, and a palette change reaches everything at once. Oxocarbon, the default, uses
overrides to keep oxocarbon.nvim's exact choices; the other themes need none.

A host chooses its theme with `settings.theme.name`, and class modules read the
result as `host.theme`, so every app on a machine shows the same one. Flake outputs
that have no host, like the README banner, use the default. Files generated entirely
from the theme live in `lib/theme/render/`.

Adding a theme takes two steps:

1. Add `lib/theme/themes/<name>.nix`. For a scheme from
   [tinted-theming/schemes](https://github.com/tinted-theming/schemes), copy its
   palette as it is and put the source URL, with its commit, at the top. A Base16
   scheme can leave out `base10` to `base17`; they fall back as the Base24 spec says.
   `name` must match the file name.

   ```nix
   # https://github.com/tinted-theming/schemes/blob/<commit>/base24/<name>.yaml
   {
     name = "<name>";
     variant = "dark";

     base00 = "#rrggbb";
     base01 = "#rrggbb";
     # … through base17
   }
   ```

2. Set it on a host:

   ```nix
   den.hosts.x86_64-linux.workstation.settings.theme.name = "<name>";
   ```

`nix flake check` runs every theme through `lib/theme/types.nix` and the pure
renderers, so a broken theme fails even before a host uses it.
