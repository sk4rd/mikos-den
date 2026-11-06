# Written to docs/banner.svg by hand, because GitHub only shows committed images.
{ config, lib, ... }:
{
  flake.banner = import ../lib/theme/render/banner.nix {
    inherit lib;
    inherit (config) theme;
  };
}
