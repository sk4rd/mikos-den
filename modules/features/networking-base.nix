{ den, ... }:

{
  den.aspects.networking-base.nixos = {
    networking = {
      networkmanager.enable = true;
      firewall.enable = true;
    };
  };

  den.schema.host.includes = [
    den.aspects.networking-base
  ];
}
