{
  # Enters a repo's devShell on cd via its .envrc; nix-direnv (on by default) caches the shell.
  den.aspects.direnv.nixos.programs.direnv.enable = true;
}
