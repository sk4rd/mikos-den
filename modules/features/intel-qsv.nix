{ den, ... }:

{
  den.aspects.intel-qsv.nixos = { pkgs, ... }: {
    hardware.enableRedistributableFirmware = true;

    hardware.graphics = {
      enable = true;
      extraPackages = [
        pkgs.intel-media-driver
        pkgs.vpl-gpu-rt
        pkgs.intel-compute-runtime
      ];
    };
  };
}
