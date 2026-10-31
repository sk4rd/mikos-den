{
  den.aspects.theme =
    { lib, ... }:
    let
      theme = import ../../lib/theme.nix;

      themeType = lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          mode = lib.mkOption {
            type = lib.types.enum [
              "dark"
              "light"
            ];
          };
          background = lib.mkOption { type = lib.types.str; };
          foreground = lib.mkOption { type = lib.types.str; };
          cursor = lib.mkOption { type = lib.types.str; };
          cursorText = lib.mkOption { type = lib.types.str; };
          selectionBackground = lib.mkOption { type = lib.types.str; };
          selectionForeground = lib.mkOption { type = lib.types.str; };
          palette = lib.mkOption { type = lib.types.attrsOf lib.types.str; };
        };
      };
    in
    {
      imports = [
        {
          options.miko.theme = lib.mkOption {
            type = themeType;
            default = theme;
            readOnly = true;
            description = "Shared theme used by Miko's application aspects.";
          };
        }
      ];
    };
}
