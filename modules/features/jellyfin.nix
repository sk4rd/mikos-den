{ den, ... }:

{
  den.aspects.jellyfin.includes = [ den.aspects.media-storage ];

  den.aspects.jellyfin.service-routes = {
    "jellyfin.sk4rd.com" = "reverse_proxy 127.0.0.1:8096";
  };

  den.aspects.jellyfin.nixos = { pkgs, ... }: {
    hardware.enableRedistributableFirmware = true;
    hardware.graphics = {
      enable = true;
      extraPackages = [
        pkgs.intel-media-driver
        pkgs.vpl-gpu-rt
        pkgs.intel-compute-runtime
      ];
    };
    services.jellyfin = {
      enable = true;
      hardwareAcceleration = {
        enable = true;
        type = "qsv";
        device = "/dev/dri/renderD128";
      };
      forceEncodingConfig = true;
      transcoding = {
        enableHardwareEncoding = true;
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          vp9 = true;
          av1 = true;
        };
      };
    };
    users.users.jellyfin.extraGroups = [
      "media"
      "render"
    ];
    systemd.services.jellyfin-storage = {
      description = "Prepare Jellyfin state";
      after = [ "media-storage.service" ];
      requires = [ "media-storage.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -m 0700 -o jellyfin -g jellyfin \
          /var/lib/media-stack/jellyfin /var/lib/media-stack/jellyfin/config /var/lib/media-stack/jellyfin/log
      '';
    };
    systemd.services.jellyfin = {
      after = [ "jellyfin-storage.service" ];
      requires = [ "jellyfin-storage.service" ];
      unitConfig.AssertPathIsMountPoint = [
        "/var/lib/media-stack"
        "/tank/data/media"
      ];
      serviceConfig = {
        BindPaths = [ "/var/lib/media-stack/jellyfin:/var/lib/jellyfin" ];
        ReadOnlyPaths = [ "/tank/data/media" ];
        InaccessiblePaths = [ "-/tank/data/media/downloads" ];
      };
    };
  };
}
