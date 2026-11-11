{ ... }:

{
  den.aspects.freecad.provides.to-users.hjem = { pkgs, ... }: {
    packages = [ pkgs.freecad ];
  };
}
