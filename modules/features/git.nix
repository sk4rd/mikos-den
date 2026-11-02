{
  den.aspects.git.hjem = { pkgs, ... }: {
    packages = [ pkgs.git ];

    files.".gitconfig".text = ''
      [init]
        defaultBranch = main
      [pull]
        rebase = true
    '';
  };
}
