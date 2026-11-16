{ den, ... }:

{
  den.aspects.jujutsu.hjem =
    { pkgs, ... }:
    {
      packages = [ pkgs.jujutsu ];
    };

  den.schema.user.includes = [ den.aspects.jujutsu ];
}
