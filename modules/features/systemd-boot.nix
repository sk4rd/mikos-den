{ den, ... }:

{
  den.aspects.systemd-boot.nixos = {
    boot.loader = {
      systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  den.schema.host.includes = [
    den.aspects.systemd-boot
  ];
}
