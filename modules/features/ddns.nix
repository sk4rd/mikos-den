{ lib, den, ... }:

{
  den.aspects.ddns = {
    includes = [ den.aspects.service-names ];

    settings = {
      zone = lib.mkOption {
        type = lib.types.str;
        default = "sk4rd.com";
        description = "Cloudflare zone that holds the public service names";
      };

      extraNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional A records kept pointed at the public IPv4";
      };
    };

    nixos =
      {
        config,
        host,
        pkgs,
        service-routes,
        ...
      }:
      let
        cfg = host.settings.ddns;
        routes = lib.foldl' (acc: entry: acc // entry) { } service-routes;
        publicNames = lib.attrNames (lib.filterAttrs (_: route: route.public or false) routes);
        names = cfg.extraNames ++ publicNames;
        nameArgs = lib.concatStringsSep " " (map lib.escapeShellArg names);
      in
      {
        systemd.services.ddns-update = {
          description = "Point the public service names at the current public IPv4";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [
            pkgs.curl
            pkgs.jq
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
            LoadCredential = "cf-token:${config.age.secrets.cloudflare-dns-token.path}";
          };
          script = ''
            set -euo pipefail

            token=$(cat "$CREDENTIALS_DIRECTORY/cf-token")
            api=https://api.cloudflare.com/client/v4
            zone=${lib.escapeShellArg cfg.zone}
            names=(${nameArgs})

            auth() { printf 'Authorization: Bearer %s' "$token"; }

            ip=$(curl -fsS --max-time 10 https://api.ipify.org)
            [ -n "$ip" ] || { echo "could not determine the public IPv4" >&2; exit 1; }

            zone_id=$(auth | curl -fsS --max-time 10 -H @- "$api/zones?name=$zone" \
              | jq -r '.result[0].id // empty')
            [ -n "$zone_id" ] || { echo "zone lookup for $zone failed" >&2; exit 1; }

            for name in "''${names[@]}"; do
              record=$(auth | curl -fsS --max-time 10 -H @- \
                "$api/zones/$zone_id/dns_records?type=A&name=$name")
              record_id=$(printf '%s' "$record" | jq -r '.result[0].id // empty')
              current=$(printf '%s' "$record" | jq -r '.result[0].content // empty')

              if [ -z "$record_id" ]; then
                auth | curl -fsS --max-time 10 -o /dev/null -X POST -H @- \
                  -H "Content-Type: application/json" \
                  --data "$(jq -n --arg name "$name" --arg ip "$ip" \
                    '{type: "A", name: $name, content: $ip, ttl: 300, proxied: false}')" \
                  "$api/zones/$zone_id/dns_records"
                echo "created $name -> $ip"
                continue
              fi

              if [ "$ip" = "$current" ]; then
                echo "$name already points at $ip"
                continue
              fi

              auth | curl -fsS --max-time 10 -o /dev/null -X PATCH -H @- \
                -H "Content-Type: application/json" \
                --data "$(jq -n --arg ip "$ip" '{content: $ip}')" \
                "$api/zones/$zone_id/dns_records/$record_id"
              echo "updated $name: $current -> $ip"
            done
          '';
        };

        systemd.timers.ddns-update = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "5min";
            Unit = "ddns-update.service";
          };
        };
      };
  };
}
