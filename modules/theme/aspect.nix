# Desktop-wide fonts. Per-app theming lives with each app.
{ config, ... }:

let
  inherit (config) theme;
in
{
  den.aspects.theme.nixos =
    { pkgs, lib, ... }:
    let
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

    };
}
