{ den, ... }:

{
  den.aspects.yazi = {
    hjem =
      { pkgs, ... }:
      {
        packages = [ pkgs.yazi ];

        # `y` hands the last directory back to the shell, so quitting yazi moves
        # the prompt instead of leaving it where it started.
        files.".config/fish/functions/y.fish".source = ../../dots/yazi/y.fish;
      };
  };

  den.schema.user.includes = [ den.aspects.yazi ];
}
