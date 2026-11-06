{ den, ... }:

{
  den.hosts.x86_64-linux.workstation = {
    users.miko = { };
    settings.proton-vpn-client = {
      publicKey = "c/PBUk5lfuqGRwA57J7SLNirHU476Op5QuihdNZZkFA=";
      endpoint = "89.222.96.187:51820";
      secret = "proton-workstation-env";
    };
  };

  den.aspects.workstation = {
    includes = [
      den.aspects.disko
      den.aspects.desktop
    ];

    provides.miko.includes = [
      den.aspects.gh
      den.aspects.obsidian
      den.aspects.learnharness
      den.aspects.voxtype
    ];

    # No idle suspend, so it stays reachable over SSH; manual sleep still works.
    # Sets one key so Plasma keeps its other power settings.
    provides.miko.hjem =
      { pkgs, ... }:
      {
        systemd.services.plasma-no-idle-sleep = {
          description = "Keep Plasma from sleeping when idle";
          wantedBy = [ "plasma-powerdevil.service" ];
          before = [ "plasma-powerdevil.service" ];
          serviceConfig.Type = "oneshot";
          script = ''
            ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file powerdevilrc \
              --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
          '';
        };
      };

    nixos = {
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
