{ inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  treefmt = inputs.treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";

    programs.nixfmt.enable = true;

    programs.stylua = {
      enable = true;
      settings = {
        indent_type = "Spaces";
        indent_width = 2;
        quote_style = "AutoPreferSingle";
      };
    };

    programs.shfmt = {
      enable = true;
      indent_size = 2;
    };
    # Indent case arms, matching the existing scripts.
    settings.formatter.shfmt.options = [ "-ci" ];

    programs.ruff-format.enable = true;
    programs.taplo.enable = true;

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
