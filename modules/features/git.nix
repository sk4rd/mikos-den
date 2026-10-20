{
  den.aspects.git.hjem = { pkgs, ... }: {
    packages = [ pkgs.git ];

    files.".gitconfig".text = ''
      [user]
        name = Mikołaj Bajtkiewicz
        email = mikolaj.ba@pm.me
      [init]
        defaultBranch = main
      [pull]
        rebase = true
    '';
  };
}
