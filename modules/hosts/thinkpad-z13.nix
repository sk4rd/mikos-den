{ inputs, den, ... }:

{
  den.hosts.x86_64-linux.thinkpad-z13 = {
    users.miko = { };
    settings.nas-vpn-client = {
      address = "10.100.0.3/32";
      secret = "wg-thinkpad-env";
    };
    settings.proton-vpn-client = {
      publicKey = "c/PBUk5lfuqGRwA57J7SLNirHU476Op5QuihdNZZkFA=";
      endpoint = "89.222.96.187:51820";
      secret = "proton-thinkpad-env";
    };
  };

  den.aspects.thinkpad-z13 = {
    includes = [
      den.aspects.disko
      den.aspects.desktop
      den.aspects.syncthing
      den.aspects.nas-vpn-client
    ];

    provides.miko.includes = [
      den.aspects.gh
      den.aspects.obsidian
    ];

    nixos = {
      imports = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1 ];

      services.fwupd.enable = true;
      services.power-profiles-daemon.enable = true;

      # Needed to stop laptop from shutting down after opening lid
      boot.blacklistedKernelModules = [ "tiny_power_button" ];

      disko.devices.disk.main = (
        import ../../lib/disks/encrypted-ext4.nix "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a481737ed"
      );
    };
  };
}
