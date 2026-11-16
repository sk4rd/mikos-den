{ den, ... }:

{
  den.aspects.yazi = {
    hjem =
      { pkgs, ... }:
      {
        packages = [ pkgs.yazi ];

        files.".config/fish/functions/y.fish".source = ../../dots/yazi/y.fish;
      };
  };

  den.schema.user.includes = [ den.aspects.yazi ];
}
