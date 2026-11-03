{ lib }:
let
  inherit (lib) mkOption types;

  hexColor = types.strMatching "#[0-9a-f]{6}" // {
    description = "lowercase #rrggbb colour";
  };

  attrPath = types.listOf types.str;

  font = types.submodule {
    options = {
      name = mkOption { type = types.str; };
      size = mkOption { type = types.ints.positive; };
      package = mkOption { type = attrPath; };
    };
  };
in
types.submodule {
  options = {
    name = mkOption { type = types.strMatching "[a-z0-9-]+"; };
    variant = mkOption {
      type = types.enum [
        "dark"
        "light"
      ];
    };

    palette = mkOption { type = types.attrsOf hexColor; };
    colors = mkOption { type = types.attrsOf (types.either hexColor (types.attrsOf hexColor)); };
    ansiNamed = mkOption { type = types.attrsOf hexColor; };
    ansi = mkOption {
      type = types.addCheck (types.listOf hexColor) (l: builtins.length l == 16) // {
        description = "list of 16 colours";
      };
    };

    fonts = mkOption {
      type = types.submodule {
        options = {
          mono = mkOption { type = font; };
          ui = mkOption { type = font; };
        };
      };
    };

    lib = mkOption { type = types.attrsOf types.raw; };
  };
}
