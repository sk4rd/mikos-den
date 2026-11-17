{ config, lib, ... }:

let
  themeType = import ../../lib/theme/types.nix { inherit lib; };
  files = lib.filterAttrs (f: type: type == "regular" && lib.hasSuffix ".nix" f) (
    builtins.readDir ../../lib/theme/themes
  );
  names = map (lib.removeSuffix ".nix") (lib.attrNames files);
in
{
  options.themes = lib.mkOption {
    type = lib.types.attrsOf themeType;
    default = lib.genAttrs names (name: import ../../lib/theme { inherit lib name; });
    readOnly = true;
    description = "Every theme in lib/theme/themes, resolved into roles.";
  };

  options.theme = lib.mkOption {
    type = themeType;
    default = config.themes.${(import ../../lib/theme { inherit lib; }).name};
    readOnly = true;
    description = "Canonical system theme. In Nix, hex literals live only in lib/theme/themes/.";
  };
}
