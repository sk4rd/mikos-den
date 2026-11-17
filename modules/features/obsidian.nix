{
  den,
  lib,
  ...
}:
{
  den.aspects.obsidian = {
    includes = [ (den.batteries.unfree [ "obsidian" ]) ];
    hjem =
      { host, pkgs, ... }:
      let
        inherit (host) theme;
        themeDir = "Notes/.obsidian/themes/${theme.name}";
      in
      {
        packages = [
          pkgs.obsidian
        ];

        files."${themeDir}/theme.css".text = import ../../lib/theme/render/obsidian.nix {
          inherit lib theme;
        };
        files."${themeDir}/manifest.json".text = builtins.toJSON {
          inherit (theme) name;
          version = "1.0.0";
          minAppVersion = "1.0.0";
          author = "miko";
        };
      };
  };
}
