{ config, inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

  pre-commit = inputs.git-hooks.lib.${system}.run {
    src = inputs.self;
    hooks = {
      # The `nix fmt` wrapper from formatter.nix, so commits and `nix fmt` share one set of rules.
      treefmt = {
        enable = true;
        package = config.flake.formatter.${system};
      };
      statix = {
        enable = true;
        # statix lints the whole directory, not the staged files, and skips only .gitignore'd
        # paths. The worktrees are excluded in .git/info/exclude, which it doesn't read.
        settings.ignore = [ ".claude/worktrees" ];
      };
      deadnix.enable = true;
    };
  };
in
{
  # Per-system merge rules, so this check and `formatting` from formatter.nix both survive.
  imports = [
    inputs.den.flakeOutputs.checks
    inputs.den.flakeOutputs.devShells
  ];

  flake.checks.${system}.pre-commit-check = pre-commit;

  flake.devShells.${system}.default = pkgs.mkShell {
    inherit (pre-commit) shellHook;
    packages = pre-commit.enabledPackages;
  };
}
