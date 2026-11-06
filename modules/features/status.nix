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

  # Endpoint groups shown as one suite: only services that depend on each other.
  suiteGroups.Media = "Media stack";

  heartbeatTokenFile = "/var/lib/status-heartbeat/env";
  # Gatus keys an endpoint as <group>_<name>, with these characters replaced by '-'.
  keyChars = [
    " "
    "/"
    "_"
    ","
    "."
    "#"
    "+"
    "&"
  ];
  slug = text: lib.replaceStrings keyChars (map (_: "-") keyChars) (lib.toLower text);
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
      pkgs,
      service-routes,
      status-endpoints,
      status-heartbeats,
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

      # always-run, because a suite otherwise skips every step after a failure and hides them.
      partitioned = lib.partition (endpoint: suiteGroups ? ${endpoint.group}) healthEndpoints;
      groupSuites = lib.mapAttrsToList (group: name: {
        inherit name group;
        interval = "60s";
        endpoints = map (
          endpoint:
          removeAttrs endpoint [
            "group"
            "interval"
          ]
          // {
            always-run = true;
          }
        ) (lib.filter (endpoint: endpoint.group == group) partitioned.right);
      }) suiteGroups;

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

      # A unit reports through OnSuccess/OnFailure = status-heartbeat@<id>.<ok|fail>.service.
      # A push missing for longer than the interval alerts too.
      heartbeats = lib.foldl' (acc: entry: acc // entry) { } status-heartbeats;
      hasHeartbeats = heartbeats != { };

      heartbeat = pkgs.writeShellApplication {
        name = "status-heartbeat";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          check=''${1%.*} result=''${1##*.}
          case $check in
            ${
              lib.concatStrings (
                lib.mapAttrsToList (id: c: ''
                  ${id}) key=${slug c.group}_${slug c.name} unit=${c.unit} ;;
                '') heartbeats
              )
            }  *) echo "unknown check $check" >&2; exit 2 ;;
          esac
          # shellcheck source=/dev/null
          source ${heartbeatTokenFile}
          args=(--data-urlencode "success=$([[ $result == ok ]] && echo true || echo false)")
          [[ $result == ok ]] || args+=(--data-urlencode "error=$unit failed, see journalctl -u $unit")
          curl -fsS --retry 3 -X POST -G "''${args[@]}" \
            -H "Authorization: Bearer $STATUS_HEARTBEAT_TOKEN" \
            "http://127.0.0.1:8081/api/v1/endpoints/$key/external"
        '';
      };
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

          endpoints = partitioned.wrong;

          external-endpoints = lib.mkIf hasHeartbeats (
            lib.mapAttrsToList (_: c: {
              inherit (c) name group;
              token = "\${STATUS_HEARTBEAT_TOKEN}";
              heartbeat.interval = c.interval;
              alerts = [
                {
                  type = "ntfy";
                  failure-threshold = 1;
                  success-threshold = 1;
                  send-on-resolved = true;
                  minimum-reminder-interval = "12h";
                }
              ];
            }) heartbeats
          );

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
          ]
          ++ groupSuites;
        };
      };

      systemd.services.gatus = {
        requires = lib.mkIf hasHeartbeats [ "status-heartbeat-token.service" ];
        serviceConfig = {
          # A fixed user, so it can own the agenix secret.
          DynamicUser = lib.mkForce false;
          User = "gatus";
          Group = "gatus";
          EnvironmentFile = lib.mkIf hasHeartbeats [ heartbeatTokenFile ];
        };
      };

      systemd.services."status-heartbeat@" = lib.mkIf hasHeartbeats {
        description = "Report result %i to Gatus";
        after = [ "gatus.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe heartbeat} %i";
        };
      };

      # Random push token, created once; readable by root and gatus only.
      systemd.services.status-heartbeat-token = lib.mkIf hasHeartbeats {
        description = "Create the Gatus heartbeat token";
        wantedBy = [ "gatus.service" ];
        before = [ "gatus.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          install -d -m 0750 -o root -g gatus ${dirOf heartbeatTokenFile}
          if [ ! -s ${heartbeatTokenFile} ]; then
            umask 0137
            printf 'STATUS_HEARTBEAT_TOKEN=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${heartbeatTokenFile}
            chgrp gatus ${heartbeatTokenFile}
          fi
        '';
      };
    };
}
