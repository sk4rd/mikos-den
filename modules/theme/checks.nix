{
  config,
  inputs,
  lib,
  ...
}:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  # Pure renderers take only lib and theme; the wallpaper needs pkgs and is built with the hosts.
  renderers = lib.filterAttrs (_: render: !(builtins.functionArgs render ? pkgs)) (
    lib.mapAttrs' (
      file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (import ../../lib/theme/render/${file})
    ) (builtins.readDir ../../lib/theme/render)
  );

  # Forcing every value runs each theme through types.nix and each pure renderer.
  rendered = lib.mapAttrs (
    _: theme:
    {
      roles = removeAttrs theme [ "lib" ];
    }
    // lib.mapAttrs (_: render: render { inherit lib theme; }) renderers
  ) config.themes;
in
{
  flake.checks.${system} = {
    theme-hex-literals =
      pkgs.runCommand "theme-hex-literals" { nativeBuildInputs = [ pkgs.ripgrep ]; }
        ''
          cd ${inputs.self}
          if rg --hidden --ignore-case --line-number '#[0-9a-f]{6}\b' \
            --glob '!lib/theme/themes/**' --glob '!docs/banner.svg' .; then
            echo 'Hex colours belong in lib/theme/themes/.' >&2
            exit 1
          fi
          touch $out
        '';

    theme-renders = pkgs.writeText "themes.json" (builtins.toJSON rendered);

    theme-banner = pkgs.runCommand "theme-banner" { } ''
      if ! diff ${../../docs/banner.svg} ${pkgs.writeText "banner.svg" config.flake.banner}; then
        echo 'docs/banner.svg is stale: nix eval --raw .#banner > docs/banner.svg' >&2
        exit 1
      fi
      touch $out
    '';
  };
}
