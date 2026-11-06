{ den, ... }:

{
  den.aspects.media-storage.includes = [ den.aspects.nas-storage ];

  den.aspects.media-storage.storage-datasets = {
    "services/media-stack" = {
      mountpoint = "/var/lib/media-stack";
      mode = "0755";
      snapshot = "working";
      props = {
        recordsize = "128K";
        compression = "zstd";
      };
    };
  };

  den.aspects.media-storage.nixos = { pkgs, ... }: {
    users.groups.media = { };

    # noauto on both: zfs-datasets creates these at multi-user, so a boot mount would hit emergency mode.
    fileSystems."/var/lib/media-stack" = {
      device = "tank/services/media-stack";
      fsType = "zfs";
      options = [
        "zfsutil"
        "noauto"
        "nofail"
        "x-systemd.requires=zfs-datasets.service"
      ];
    };
    fileSystems."/tank/data/media" = {
      device = "tank/data/media";
      fsType = "zfs";
      options = [
        "zfsutil"
        "noauto"
        "nofail"
        "x-systemd.requires=zfs-datasets.service"
      ];
    };

    systemd.services.media-storage = {
      description = "Prepare media service state and shared directories";
      wantedBy = [ "multi-user.target" ];
      after = [ "zfs-datasets.service" ];
      requires = [ "zfs-datasets.service" ];
      unitConfig = {
        RequiresMountsFor = [
          "/var/lib/media-stack"
          "/tank/data/media"
        ];
        AssertPathIsMountPoint = [
          "/var/lib/media-stack"
          "/tank/data/media"
        ];
      };
      path = [
        pkgs.coreutils
        pkgs.acl
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        mkdir -p /tank/data/media/Movies /tank/data/media/Shows
        for dir in /tank/data/media /tank/data/media/Movies /tank/data/media/Shows; do
          setfacl -m g:media:rwx,d:g:media:rwx "$dir"
        done
      '';
    };

  };
}
