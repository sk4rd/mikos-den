{ lib, den, ... }:

{
  den.aspects.seerr.includes = [ den.aspects.media-storage ];

  den.aspects.seerr.service-routes = {
    "seerr.sk4rd.com" = {
      proxy = "reverse_proxy 127.0.0.1:5055";
    };
  };

  den.aspects.seerr.status-endpoints = [
    {
      name = "Seerr";
      group = "Media";
      url = "http://127.0.0.1:5055/";
      conditions = [ "[STATUS] == any(200, 302, 307, 401)" ];
    }
  ];

  den.aspects.seerr.nixos = { pkgs, ... }: {
    services.seerr = {
      enable = true;
      stateRevision = 1;
    };
    users.users.seerr = {
      isSystemUser = true;
      group = "seerr";
    };
    users.groups.seerr = { };
    systemd.services.seerr-storage = {
      description = "Prepare Seerr state";
      after = [ "media-storage.service" ];
      requires = [ "media-storage.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -m 0700 -o seerr -g seerr /var/lib/media-stack/seerr
      '';
    };
    systemd.services.seerr = {
      after = [ "seerr-storage.service" ];
      requires = [ "seerr-storage.service" ];
      unitConfig.AssertPathIsMountPoint = "/var/lib/media-stack";
      serviceConfig = {
        # A fixed user, because its state on the dataset outlives the service.
        DynamicUser = lib.mkForce false;
        User = "seerr";
        Group = "seerr";
        BindPaths = [ "/var/lib/media-stack/seerr:/var/lib/seerr" ];
      };
    };
  };
}
