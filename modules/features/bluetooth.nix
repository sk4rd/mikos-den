{ den, ... }:

{
  den.aspects.bluetooth.nixos.hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  den.schema.host.includes = [ den.aspects.bluetooth ];
}
