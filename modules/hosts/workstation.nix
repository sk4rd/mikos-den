{ den, ... }:

{
  den.hosts.x86_64-linux.workstation = { };

  den.aspects.workstation = {
    includes = [
      den.aspects.disko
      den.aspects.plasma
      den.aspects.brave
      den.aspects.gaming
      den.aspects.audio
      den.aspects.bluetooth
      den.aspects.flatpak
    ];

    nixos = {
      system.stateVersion = "26.11";

      hardware = {
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = true;
        amdgpu.initrd.enable = true;
        graphics.enable = true;
      };

      services.xserver.videoDrivers = [ "amdgpu" ];

      boot.kernelParams = [ "amd_pstate=active" ];

      disko.devices.disk.main = (
        import ../../lib/disks/encrypted-ext4.nix "/dev/disk/by-id/nvme-CT4000P3PSSD8_2339E879EA19"
      );
    };
  };
}
