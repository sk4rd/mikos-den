{ inputs, ... }:

{
  # Include this aspect if you want to manage disks with disko
  den.aspects.disko.nixos.imports = [ inputs.disko.nixosModules.disko ];
}
