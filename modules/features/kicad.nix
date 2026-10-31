{ ... }:

{
  den.aspects.kicad.provides.to-users.hjem = { pkgs, ... }: {
    packages = [ pkgs.kicad ];
  };
}
