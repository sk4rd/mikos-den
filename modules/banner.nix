# Written to docs/banner.svg by hand, because GitHub only shows committed images.
{ lib, ... }:
{
  flake.banner = import ../lib/theme/render/banner.nix {
    inherit lib;
    theme = import ../lib/theme { inherit lib; };
  };
}
