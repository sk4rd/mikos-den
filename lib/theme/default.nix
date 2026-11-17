{
  lib,
  name ? "oxocarbon",
}:
let
  theme = import ./themes/${name}.nix;
in
assert lib.assertMsg (theme.name == name) "lib/theme/themes/${name}.nix is named ${theme.name}";
import ./roles.nix { inherit lib; } theme
