{ den, ... }:

{
  den.hosts.x86_64-linux.workstation = {
    users.miko = { };
    settings.proton-vpn-client = {
      publicKey = "c/PBUk5lfuqGRwA57J7SLNirHU476Op5QuihdNZZkFA=";
      endpoint = "89.222.96.187:51820";
      secret = "proton-workstation-env";
    };
    # No idle suspend, so it stays reachable over SSH; manual sleep still works.
    settings.noctalia.idleSuspendSeconds = null;
  };

  den.aspects.workstation = {
    includes = [
      den.aspects.disko
      den.aspects.desktop
      den.aspects.syncthing
    ];

    provides.miko.includes = [
      den.aspects.gh
      den.aspects.obsidian
      den.aspects.learnharness
      den.aspects.voxtype
      den.aspects.ai
    ];

    provides.miko.hjem.files.".config/umbriel/conf.d/host.toml".text = ''
      [output.DP-1]
      mode = "3440x1440@175"

      [output.DP-2]
      mode = "2560x1440@165"

    '';

    nixos = {
      # LAN IP allowlist: includes masqueraded VPN peers and everything the NAS itself sends.
      networking.firewall.extraCommands =
        let
          network = import ../../lib/network.nix;
        in
        "iptables -w -I nixos-fw 1 -s ${network.nasLanAddress}/32 -j nixos-fw-accept";

      hardware = {
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = true;
        amdgpu.initrd.enable = true;
        graphics.enable = true;
      };

      services.xserver.videoDrivers = [ "amdgpu" ];

      boot.kernelParams = [ "amd_pstate=active" ];

      # Wait at the menu: the JetKVM can take until the disk unlock prompt to get a
      # picture. The unlock prompt stops an unattended boot anyway.
      boot.loader.timeout = null;

      # The firmware starts on the integrated GPU so the JetKVM gets its picture, which
      # would also make that GPU the compositor's main one. wlroots splits this list on
      # ":", which rules out the by-path names, so the GPUs get names of their own.
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", KERNEL=="card[0-9]", KERNELS=="0000:03:00.0", SYMLINK+="dri/rx7900"
        SUBSYSTEM=="drm", KERNEL=="card[0-9]", KERNELS=="0000:13:00.0", SYMLINK+="dri/igpu"
      '';
      environment.sessionVariables = {
        WLR_DRM_DEVICES = "/dev/dri/rx7900:/dev/dri/igpu";
        DRI_PRIME = "pci-0000_03_00_0";
      };

      # A boot menu entry where the JetKVM on the motherboard's HDMI-A-2 is the only
      # display, from the disk unlock prompt onwards. Every other connector is switched off.
      specialisation.jetkvm.configuration.boot.kernelParams = map (connector: "video=${connector}:d") [
        "DP-1"
        "DP-2"
        "DP-3"
        "DP-4"
        "DP-5"
        "DP-6"
        "HDMI-A-1"
      ];

      disko.devices.disk.main = import ../../lib/disks/encrypted-ext4.nix "/dev/disk/by-id/nvme-CT4000P3PSSD8_2339E879EA19";
    };
  };
}
