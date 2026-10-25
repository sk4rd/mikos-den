{ lib, den, ... }:

let
  props = {
    recordsize = "128K";
    compression = "zstd";
  };

  tankDatasets = {
    "data" = {
      canmount = "off";
    };
    "data/documents" = {
      inherit props;
    };
    "data/projects" = {
      inherit props;
    };
    "data/media" = {
      props = {
        recordsize = "1M";
        compression = "off";
      };
    };
    "data/personal" = {
      inherit props;
    };
    "data/public" = {
      inherit props;
    };
    "data/torrents" = {
      props = {
        recordsize = "1M";
        compression = "lz4";
        refquota = "2T";
      };
    };
    "services" = {
      canmount = "off";
    };
    "services/home-assistant" = {
      mountpoint = "/var/lib/hass";
      owner = "hass";
      group = "hass";
      mode = "0750";
      inherit props;
    };
    "backups" = {
      canmount = "off";
    };
    "private" = {
      owner = "miko";
      group = "users";
      mode = "0700";
    };
  };

  datasetBlock =
    name: cfg:
    let
      ds = "tank/${name}";
      mountpoint = cfg.mountpoint or "/tank/${name}";
      properties = [
        {
          name = "mountpoint";
          value = mountpoint;
        }
        {
          name = "canmount";
          value = cfg.canmount or "on";
        }
      ]
      ++ lib.mapAttrsToList (name: value: { inherit name value; }) (cfg.props or { });

      dsArg = lib.escapeShellArg ds;
      mountpointArg = lib.escapeShellArg mountpoint;

      setIfChanged =
        property:
        let
          propertyArg = lib.escapeShellArg "${property.name}=${property.value}";
          nameArg = lib.escapeShellArg property.name;
          valueArg = lib.escapeShellArg property.value;
        in
        ''
          if [ "$(zfs get -H -o value ${nameArg} ${dsArg} 2>/dev/null || true)" != ${valueArg} ]; then
            zfs set ${propertyArg} ${dsArg}
          fi
        '';

      createArgs = lib.concatMap (property: [
        "-o"
        "${property.name}=${property.value}"
      ]) properties;

      ownerScript = lib.optionalString (cfg ? owner) ''
        chown ${lib.escapeShellArg "${cfg.owner}:${cfg.group or cfg.owner}"} ${mountpointArg}
      '';

      modeScript = lib.optionalString (cfg ? mode || cfg ? owner) ''
        if [ "$(zfs get -H -o value mounted ${dsArg})" != "yes" ]; then
          zfs mount ${dsArg}
        fi
        ${ownerScript}
        ${lib.optionalString (cfg ? mode) "chmod ${lib.escapeShellArg cfg.mode} ${mountpointArg}"}
      '';
    in
    ''
      if zfs list -H -o name ${dsArg} >/dev/null 2>&1; then
        ${lib.concatMapStringsSep "\n" setIfChanged properties}
      else
        zfs create ${lib.escapeShellArgs (createArgs ++ [ ds ])}
      fi
      ${modeScript}
    '';
in

{
  den.hosts.x86_64-linux.nas = { };

  den.aspects.nas = {
    includes = [
      den.aspects.disko
      den.aspects.home-assistant
      den.aspects.service-names
    ];

    nixos =
      {
        config,
        pkgs,
        ...
      }:
      let
        layoutScript = lib.concatMapAttrsStringSep "\n" datasetBlock tankDatasets;
      in
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
          supportedFilesystems = [ "zfs" ];
          zfs.extraPools = [ "tank" ];
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

        # Cloudflare DNS token: DDNS for vpn.sk4rd.com and DNS-01 certs.
        age.secrets.cloudflare-dns-token = {
          file = ../../secrets/cloudflare-dns-token.age;
          owner = "caddy";
        };

        systemd.services.ddns-update = {
          description = "Point vpn.sk4rd.com at the current public IPv4";
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
            name=vpn.sk4rd.com

            auth() { printf 'Authorization: Bearer %s\n' "$token"; }

            ip=$(curl -fsS --max-time 10 https://api.ipify.org)
            [ -n "$ip" ] || { echo "could not determine the public IPv4" >&2; exit 1; }

            zone_id=$(auth | curl -fsS --max-time 10 -H @- "$api/zones?name=$zone" \
              | jq -r '.result[0].id // empty')
            [ -n "$zone_id" ] || { echo "zone lookup for $zone failed" >&2; exit 1; }

            record=$(auth | curl -fsS --max-time 10 -H @- \
              "$api/zones/$zone_id/dns_records?type=A&name=$name")
            record_id=$(printf '%s' "$record" | jq -r '.result[0].id // empty')
            current=$(printf '%s' "$record" | jq -r '.result[0].content // empty')
            [ -n "$record_id" ] || { echo "no A record for $name" >&2; exit 1; }

            if [ "$ip" = "$current" ]; then
              echo "$name already points at $ip"
              exit 0
            fi

            auth | curl -fsS --max-time 10 -o /dev/null -X PATCH -H @- \
              -H "Content-Type: application/json" \
              --data "$(jq -n --arg ip "$ip" '{content: $ip}')" \
              "$api/zones/$zone_id/dns_records/$record_id"
            echo "updated $name: $current -> $ip"
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

        services.zfs = {
          autoScrub.enable = true;
          expandOnBoot = "all";
        };

        services.sanoid = {
          enable = true;
          interval = "hourly";
          templates.working = {
            hourly = 24;
            daily = 7;
            weekly = 4;
            monthly = 3;
            autosnap = true;
            autoprune = true;
          };
          templates.archive = {
            daily = 7;
            weekly = 4;
            monthly = 6;
            autosnap = true;
            autoprune = true;
          };
          datasets = {
            "tank/data/documents" = {
              useTemplate = [ "working" ];
            };
            "tank/data/personal" = {
              useTemplate = [ "working" ];
            };
            "tank/data/projects" = {
              useTemplate = [ "working" ];
            };
            "tank/data/public" = {
              useTemplate = [ "archive" ];
            };
            "tank/private" = {
              useTemplate = [ "working" ];
            };
          };
        };

        systemd.services.zfs-datasets = {
          description = "Apply the declarative dataset layout on tank";
          wantedBy = [ "multi-user.target" ];
          after = [
            "zfs-import.target"
            "zfs-mount.service"
          ];
          requires = [ "zfs-import.target" ];
          path = [
            config.boot.zfs.package
            pkgs.coreutils
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu

            if ! zpool list -H -o name tank >/dev/null 2>&1; then
              echo "zfs-datasets: pool tank is not imported" >&2
              exit 1
            fi

            ${layoutScript}
          '';
        };
      };
  };
}
