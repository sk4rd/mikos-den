{ den, ... }:

{
  den.hosts.x86_64-linux.nas = { };

  den.aspects.nas = {
    provides.miko.includes = [ den.aspects.media-access ];
    includes = [
      den.aspects.disko
      den.aspects.nas-storage
      den.aspects.home-assistant
      den.aspects.media-downloads
      den.aspects.servarr
      den.aspects.jellyfin
      den.aspects.seerr
      den.aspects.service-names
    ];

    nixos =
      {
        config,
        pkgs,
        ...
      }:
      {
        system.stateVersion = "26.11";

        disko.devices = {
          disk.main = {
            device = "/dev/disk/by-id/ata-WDC_WDS240G1G0B-00RC30_1711A9801663";
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "2G";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    extraArgs = [
                      "-F"
                      "32"
                    ];
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };
                zfs = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = "rpool";
                  };
                };
              };
            };
          };

          zpool.rpool = {
            type = "zpool";
            options = {
              ashift = "12";
              autotrim = "on";
            };
            rootFsOptions = {
              mountpoint = "none";
              canmount = "off";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              acltype = "posixacl";
              dnodesize = "auto";
            };
            datasets = {
              root = {
                type = "zfs_fs";
                mountpoint = "/";
              };
              nix = {
                type = "zfs_fs";
                mountpoint = "/nix";
              };
              var = {
                type = "zfs_fs";
                mountpoint = "/var";
              };
              "var/log" = {
                type = "zfs_fs";
                mountpoint = "/var/log";
                options.quota = "5G";
              };
              home = {
                type = "zfs_fs";
                mountpoint = "/home";
              };
            };
          };
        };

        boot = {
          kernelParams = [ "zfs.zfs_arc_max=4294967296" ];
        };

        security.sudo.wheelNeedsPassword = false;

        networking = {
          hostName = "nas";

          # Carried over from the previous install for zfs
          hostId = "6985f698";

          networkmanager.ensureProfiles.profiles.enp1s0 = {
            connection = {
              id = "enp1s0";
              type = "ethernet";
              interface-name = "enp1s0";
              autoconnect = true;
            };
            ipv4 = {
              method = "manual";
              addresses = "192.168.178.3/24";
              gateway = "192.168.178.1";
              dns = "192.168.178.1";
            };
          };
        };

        age.secrets.wg-server-key.file = ../../secrets/wg-server-key.age;

        networking.wireguard.interfaces.wg0 = {
          ips = [ "10.100.0.1/24" ];
          listenPort = 51820;
          privateKeyFile = config.age.secrets.wg-server-key.path;
          peers = [
            {
              # workstation
              publicKey = "fQ6d2wm3vg44c782BN5uaddSeSyy40alcQhjISsELzA=";
              allowedIPs = [ "10.100.0.2/32" ];
            }
            {
              # thinkpad-z13
              publicKey = "QUiRCvPcetsdkeRGM3NIxD5amJdDqxM6CZdMQY4RTzU=";
              allowedIPs = [ "10.100.0.3/32" ];
            }
            {
              # phone
              publicKey = "rajGvU9NK6lHJm3ncM2PGZB22xbuw2cnmc66oOstcE4=";
              allowedIPs = [ "10.100.0.4/32" ];
            }
          ];
        };

        networking.firewall = {
          allowedUDPPorts = [ 51820 ];
          trustedInterfaces = [ "wg0" ];
        };

        systemd.services.wireguard-wg0.restartTriggers = [
          (builtins.hashFile "sha256" ../../secrets/wg-server-key.age)
        ];

        networking.nat = {
          enable = true;
          internalInterfaces = [ "wg0" ];
          externalInterface = "enp1s0";
        };

        boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

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
            zone=sk4rd.com
            names=(vpn.sk4rd.com jellyfin.sk4rd.com)

            auth() { printf 'Authorization: Bearer %s\n' "$token"; }

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
