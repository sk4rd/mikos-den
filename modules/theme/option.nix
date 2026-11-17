{ lib, ... }:

let
  files = lib.filterAttrs (f: type: type == "regular" && lib.hasSuffix ".nix" f) (
    builtins.readDir ../../lib/theme/themes
  );
  names = map (lib.removeSuffix ".nix") (lib.attrNames files);
in
{
  options.themes = lib.mkOption {
    type = lib.types.attrsOf (import ../../lib/theme/types.nix { inherit lib; });
    default = lib.genAttrs names (name: import ../../lib/theme { inherit lib name; });
    readOnly = true;
    description = "Every theme in lib/theme/themes/, resolved into roles. Class modules read their host's as host.theme.";
  };
}
