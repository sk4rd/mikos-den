{ inputs, den, ... }:

{
  den.hosts.x86_64-linux.thinkpad-z13 = {
    users.miko = { };
    settings = {
      nas-vpn-client = {
        secret = "wg-thinkpad-env";
      };
      proton-vpn-client = {
        publicKey = "c/PBUk5lfuqGRwA57J7SLNirHU476Op5QuihdNZZkFA=";
        endpoint = "89.222.96.187:51820";
        secret = "proton-thinkpad-env";
      };
      noctalia.idleSuspendSeconds = 900;
    };
  };

  den.aspects.thinkpad-z13 = {
    includes = [
      den.aspects.disko
      den.aspects.desktop
      den.aspects.nas-vpn-client
      den.aspects.syncthing
      den.aspects.direnv
    ];

    provides.miko.includes = [
      den.aspects.gh
      den.aspects.obsidian
      den.aspects.learnharness
      den.aspects.voxtype
      den.aspects.ai
    ];

    provides.miko.hjem.files.".config/umbriel/conf.d/host.toml".text = ''
      [output.eDP-1]
      scale = 1.65
    '';

    nixos = {
      imports = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z13-gen1 ];

      services.fwupd.enable = true;

      # Password only at login (and greetd), so gnome-keyring gets it to unlock.
      security.pam.services.login.fprintAuth = false;

      # Needed to stop laptop from shutting down after opening lid
      boot.blacklistedKernelModules = [ "tiny_power_button" ];

      disko.devices.disk.main = import ../../lib/disks/encrypted-ext4.nix "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a481737ed";
    };
  };
}
