{ lib, den, ... }:

let
  ntfyTopic = "\${NTFY_TOPIC}";
  ntfyAlert = {
    type = "ntfy";
    failure-threshold = 3;
    success-threshold = 2;
    send-on-resolved = true;
    minimum-reminder-interval = "1h";
  };
in
{
  den.aspects.status.includes = [
    den.aspects.service-names
    den.aspects.secrets
  ];

  den.aspects.status.service-routes = {
    "status.sk4rd.com" = {
      proxy = "reverse_proxy 127.0.0.1:8081";
    };
  };

  den.aspects.status.nixos =
    {
      config,
      host,
      service-routes,
      status-endpoints,
      ...
    }:
    let
      routes = lib.foldl' (acc: entry: acc // entry) { } service-routes;
      publicNames = lib.attrNames (lib.filterAttrs (_: route: route.public or false) routes);
      ddnsNames = (host.settings.ddns.extraNames or [ ]) ++ publicNames;
      healthEndpoints = map (
        endpoint:
        {
          interval = "60s";
          alerts = [ ntfyAlert ];
        }
        // endpoint
      ) status-endpoints;

      ddnsEndpoints = map (name: {
        name = "DDNS ${name}";
        url = "1.1.1.1";
        dns = {
          query-name = name;
          query-type = "A";
        };
        conditions = [
          "[DNS_RCODE] == NOERROR"
          "[BODY] == [CONTEXT].public_ip"
        ];
        alerts = [ ntfyAlert ];
      }) ddnsNames;
    in
    {
      age.secrets.gatus-env = {
        file = ../../secrets/gatus-env.age;
        owner = "gatus";
        group = "gatus";
        mode = "0400";
      };

      users.groups.gatus = { };
      users.users.gatus = {
        isSystemUser = true;
        group = "gatus";
      };

      services.gatus = {
        enable = true;
        environmentFile = config.age.secrets.gatus-env.path;

        settings = {
          web = {
            address = "127.0.0.1";
            port = 8081;
          };

          ui = {
            header = "mikos-den";
            dashboard-heading = "Service status";
            dashboard-subheading = "NAS, media and VPN health";
            dark-mode = true;
          };

          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/data.db";
          };

          alerting.ntfy = {
            topic = ntfyTopic;
            priority = 4;
            click = "https://status.sk4rd.com";
            default-alert = {
              failure-threshold = 3;
              success-threshold = 2;
              send-on-resolved = true;
              minimum-reminder-interval = "1h";
            };
          };

          endpoints = healthEndpoints;

          suites = [
            {
              name = "DDNS records";
              group = "Core";
              interval = "60s";
              endpoints = [
                {
                  name = "Public IPv4";
                  url = "https://api.ipify.org";
                  conditions = [ "[STATUS] == 200" ];
                  store = {
                    public_ip = "[BODY]";
                  };
                  alerts = [ ntfyAlert ];
                }
              ]
              ++ ddnsEndpoints;
            }
          ];
        };
      };

      systemd.services.gatus.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "gatus";
        Group = "gatus";
      };
    };
}
