{ den, ... }:

{
  den.aspects.systemd-boot.nixos = {
    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.editor = false;
      efi.canTouchEfiVariables = true;
    };
  };

  den.schema.host.includes = [
    den.aspects.systemd-boot
  ];
}
