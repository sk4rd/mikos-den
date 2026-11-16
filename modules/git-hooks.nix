{ inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  pre-commit = inputs.git-hooks.lib.${system}.run {
    src = inputs.self;
    hooks = {
      statix.enable = true;
      deadnix.enable = true;
    };
  };
in
{
  imports = [
    inputs.den.flakeOutputs.checks
    inputs.den.flakeOutputs.devShells
  ];

  flake.checks.${system}.pre-commit-check = pre-commit;

  flake.devShells.${system}.default = pkgs.mkShell {
    packages = pre-commit.enabledPackages;
  };
}
