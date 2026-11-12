{ den, ... }:

let
  network = import ../../lib/network.nix;
in
{
  den.hosts.x86_64-linux.nas = {
    users.miko = { };

    settings.wireguard-server = {
      wanInterface = "enp1s0";
      peers = [
        {
          publicKey = "QUiRCvPcetsdkeRGM3NIxD5amJdDqxM6CZdMQY4RTzU=";
          allowedIPs = [ "10.100.0.3/32" ];
        }
        {
          publicKey = "rajGvU9NK6lHJm3ncM2PGZB22xbuw2cnmc66oOstcE4=";
          allowedIPs = [ "10.100.0.4/32" ];
        }
        {
          # iPhone
          publicKey = "ZL9PsG2Rmm6e3ncYdRL4jem0bu2aZzJPEz/wGq/nMms=";
          allowedIPs = [ "10.100.0.5/32" ];
        }
      ];
    };

    settings.ddns.extraNames = [ "vpn.sk4rd.com" ];
  };

  den.aspects.nas = {
    provides.miko.user.extraGroups = [ "media" ];
    includes = [
      den.aspects.disko
      den.aspects.nas-storage
      den.aspects.wireguard-server
      den.aspects.ddns
      den.aspects.home-assistant
      den.aspects.media-downloads
      den.aspects.servarr
      den.aspects.jellyfin
      den.aspects.seerr
      den.aspects.service-names
      den.aspects.media-vpn-health
      den.aspects.status
      den.aspects.livesync
      den.aspects.proton-backup
    ];

    nixos =
      {
        ...
      }:
      {
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
              addresses = "${network.nasLanAddress}/${network.lanPrefixLength}";
              gateway = network.routerAddress;
              dns = network.routerAddress;
            };
          };
        };

      };
  };
}
