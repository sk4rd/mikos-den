{
  den.aspects.networking-base.nixos = {
    networking = {
      networkmanager.enable = true;
      firewall.enable = true;
    };
  };
}
