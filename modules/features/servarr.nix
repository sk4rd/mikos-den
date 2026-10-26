{ lib, den, ... }:

{
  den.aspects.servarr.includes = [
    den.aspects.media-storage
    den.aspects.flaresolverr
  ];

  den.aspects.servarr.service-routes = {
    "sonarr.sk4rd.com" = "reverse_proxy 127.0.0.1:8989";
    "radarr.sk4rd.com" = "reverse_proxy 127.0.0.1:7878";
    "prowlarr.sk4rd.com" = "reverse_proxy 127.0.0.1:9696";
  };

  den.aspects.servarr.nixos = { pkgs, ... }: {
    services.sonarr = {
      enable = true;
      settings.server.bindaddress = "127.0.0.1";
    };
    services.radarr = {
      enable = true;
      settings.server.bindaddress = "127.0.0.1";
    };
    services.prowlarr = {
      enable = true;
      settings.server.bindaddress = "127.0.0.1";
    };

    users.users.prowlarr = {
      isSystemUser = true;
      group = "prowlarr";
    };
    users.groups.prowlarr = { };
    users.users.sonarr.extraGroups = [ "media" ];
    users.users.radarr.extraGroups = [ "media" ];

    systemd.services =
      lib.genAttrs [ "sonarr" "radarr" "prowlarr" ] (app: {
        after = [ "${app}-storage.service" ];
        requires = [ "${app}-storage.service" ];
        unitConfig.AssertPathIsMountPoint = [
          "/var/lib/media-stack"
          "/tank/data/media"
        ];
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = app;
          Group = app;
          UMask = lib.mkForce "0002";
          BindPaths = [ "/var/lib/media-stack/${app}:/var/lib/${app}" ];
        }
        // lib.optionalAttrs (app != "prowlarr") {
          ProtectSystem = "strict";
          ReadWritePaths = [
            "/tank/data/media"
            "/var/lib/${app}"
          ];
        };
      })
      // lib.genAttrs [ "sonarr-storage" "radarr-storage" "prowlarr-storage" ] (
        name:
        let
          app = lib.removeSuffix "-storage" name;
          subdir =
            {
              sonarr = ".config/NzbDrone";
              radarr = ".config/Radarr";
              prowlarr = ".";
            }
            .${app};
        in
        {
          description = "Prepare ${app} state";
          after = [ "media-storage.service" ];
          requires = [ "media-storage.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.coreutils}/bin/install -d -m 0700 -o ${app} -g ${app} \
              /var/lib/media-stack/${app} /var/lib/media-stack/${app}/${subdir}
          '';
        }
      );
  };
}
