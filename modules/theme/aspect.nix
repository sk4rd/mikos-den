{ config, lib, ... }:

let
  inherit (config) themes;
  themeType = import ../../lib/theme/types.nix { inherit lib; };
in
{
  den.aspects.theme = {
    settings.name = lib.mkOption {
      type = lib.types.enum (lib.attrNames themes);
      default = (import ../../lib/theme { inherit lib; }).name;
      description = "Theme for this host: the name of a file in lib/theme/themes/. Class modules read it resolved as host.theme.";
    };

    nixos =
      { host, pkgs, ... }:
      let
        inherit (host) theme;
        pkg = path: lib.getAttrFromPath path pkgs;
      in
      {
        fonts.packages = [
          (pkg theme.fonts.ui.package)
          (pkg theme.fonts.mono.package)
        ];

        fonts.fontconfig.defaultFonts = {
          sansSerif = [ theme.fonts.ui.name ];
          monospace = [ theme.fonts.mono.name ];
        };

        # The default background is colour 0, which ansi keeps lighter for terminals.
        console.colors = map theme.lib.bare ([ theme.colors.bg ] ++ lib.tail theme.ansi);
      };
  };

  den.schema.host.imports = [
    (
      { config, ... }:
      {
        options.theme = lib.mkOption {
          type = themeType;
          default = themes.${config.settings.theme.name};
          readOnly = true;
          description = "The theme `settings.theme.name` selects, resolved into roles";
        };
      }
    )
  ];
}
