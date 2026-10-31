{ den, ... }:

{
  den.aspects.fzf.hjem = { pkgs, ... }: {
    packages = [ pkgs.fzf ];

    files.".config/fish/conf.d/fzf.fish".text = ''
      if type -q fzf
          fzf --fish | source
      end
    '';
  };

  den.schema.user.includes = [ den.aspects.fzf ];
}
