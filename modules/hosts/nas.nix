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
    "backups" = {
      canmount = "off";
    };
    "private" = {
      mode = "0700";
    };
  };

  datasetBlock =
    name: cfg:
    let
      ds = "tank/${name}";
      mountpoint = cfg.mountpoint or "/tank/${name}";
      pairs = [
        "mountpoint=${mountpoint}"
        "canmount=${cfg.canmount or "on"}"
      ]
      ++ lib.mapAttrsToList (k: v: "${k}=${v}") (cfg.props or { });

      modeScript = lib.optionalString (cfg ? mode) ''
        if [ "$(zfs get -H -o value mounted ${ds})" != "yes" ]; then
          zfs mount ${ds}
        fi
        chmod ${cfg.mode} ${mountpoint}
      '';
    in
    ''
      if zfs list -H -o name ${ds} >/dev/null 2>&1; then
        zfs set ${lib.escapeShellArgs (pairs ++ [ ds ])}
      else
        zfs create ${
          lib.escapeShellArgs (
            lib.concatMap (p: [
              "-o"
              p
            ]) pairs
            ++ [ ds ]
          )
        }
      fi
      ${modeScript}
    '';

  layoutScript = lib.concatStringsSep "\n" (lib.mapAttrsToList datasetBlock tankDatasets);
in

{
  den.hosts.x86_64-linux.nas = { };

  den.aspects.nas = {
    includes = [ den.aspects.disko ];

    nixos =
      { config, pkgs, ... }:
      {
        system.stateVersion = "26.11"; # No need to change this line

        # Configure boot ssd zfs pool
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

        # Wireguard config
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

        # Restart wireguard when key changes
        systemd.services.wireguard-wg0.restartTriggers = [
          (builtins.hashFile "sha256" ../../secrets/wg-server-key.age)
        ];

        networking.nat = {
          enable = true;
          internalInterfaces = [ "wg0" ];
          externalInterface = "enp1s0";
        };

        boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
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
