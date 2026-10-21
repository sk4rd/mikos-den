{ inputs, den, ... }:

{
  den.hosts.x86_64-linux.thinkpad-z13 = { };

  den.aspects.thinkpad-z13 = {
    includes = [
      den.aspects.disko
      den.aspects.plasma
      den.aspects.brave
      den.aspects.gaming
    ];

    nixos = {
      imports = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1 ];

      system.stateVersion = "26.11"; # No need to change this line

      # Laptop hardware support
      services.fwupd.enable = true;
      services.power-profiles-daemon.enable = true;

      # Manage disk with disko
      disko.devices.disk.main = (
        import ../../lib/disks/encrypted-ext4.nix "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a481737ed"
      );
    };
  };
}
