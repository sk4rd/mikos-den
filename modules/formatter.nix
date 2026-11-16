{ inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  treefmt = inputs.treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";

    programs = {
      nixfmt.enable = true;

      stylua = {
        enable = true;
        settings = {
          indent_type = "Spaces";
          indent_width = 2;
          quote_style = "AutoPreferSingle";
        };
      };

      shfmt = {
        enable = true;
        indent_size = 2;
      };

      ruff-format.enable = true;
      taplo.enable = true;
    };

    settings.formatter.shfmt.options = [ "-ci" ];

    settings.global.excludes = [
      "secrets/*.age"
      "flake.lock"
      "*.md"
    ];
  };
in
{
  flake.formatter.${system} = treefmt.config.build.wrapper;
  flake.checks.${system}.formatting = treefmt.config.build.check inputs.self;
}
