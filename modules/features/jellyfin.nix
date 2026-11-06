{ den, ... }:

{
  den.aspects.jellyfin.includes = [
    den.aspects.media-storage
    den.aspects.intel-qsv
  ];

  den.aspects.jellyfin.service-routes = {
    "jellyfin.sk4rd.com" = {
      proxy = "reverse_proxy 127.0.0.1:8096";
      public = true;
    };
  };

  den.aspects.jellyfin.status-endpoints = [
    {
      name = "Jellyfin";
      group = "Media";
      url = "http://127.0.0.1:8096/health";
      conditions = [ "[STATUS] == 200" ];
    }
  ];

  den.aspects.jellyfin.nixos = { pkgs, ... }: {
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
        # Incomplete downloads stay out of the library.
        InaccessiblePaths = [ "-/tank/data/media/downloads" ];
      };
    };
  };
}
