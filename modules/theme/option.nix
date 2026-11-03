# The canonical theme (lib/theme), exposed to every module as `config.theme`.
{ lib, ... }:

{
  options.theme = lib.mkOption {
    type = import ../../lib/theme/types.nix { inherit lib; };
    default = import ../../lib/theme { inherit lib; };
    readOnly = true;
    description = "Canonical system theme. Hex literals live only in lib/theme/oxocarbon.nix.";
  };
}
