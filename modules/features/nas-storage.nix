{ lib, ... }:

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
      snapshot = "working";
      inherit props;
    };
    "data/projects" = {
      snapshot = "working";
      inherit props;
    };
    # Video is already compressed, and large records suit big sequential files.
    "data/media" = {
      props = {
        recordsize = "1M";
        compression = "off";
      };
    };
    "data/personal" = {
      snapshot = "working";
      inherit props;
    };
    "data/public" = {
      snapshot = "archive";
      inherit props;
    };
    # The quota keeps downloads from filling the pool.
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
      snapshot = "working";
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
  den.aspects.nas-storage.nixos =
    {
      config,
      pkgs,
      storage-datasets,
      ...
    }:
    let
      datasets = lib.foldl' (acc: entry: acc // entry) tankDatasets storage-datasets;
      names = lib.concatMap builtins.attrNames storage-datasets;
      layoutScript = lib.concatMapAttrsStringSep "\n" datasetBlock datasets;
    in
    {
      boot.supportedFilesystems = [ "zfs" ];
      boot.zfs.extraPools = [ "tank" ];
      assertions = [
        {
          assertion =
            builtins.length names == builtins.length (lib.unique names)
            && lib.all (name: !(builtins.hasAttr name tankDatasets)) names;
          message = "Dataset contributions must have unique names and not override base datasets";
        }
      ];
      services.zfs = {
        autoScrub.enable = true;
        expandOnBoot = "all";
      };

      services.sanoid = {
        enable = true;
        interval = "hourly";
        # working changes often, so it gets hourly snapshots; archive rarely does, so it keeps more months.
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
        datasets = lib.mapAttrs' (
          name: cfg:
          lib.nameValuePair "tank/${name}" {
            useTemplate = [ cfg.snapshot ];
          }
        ) (lib.filterAttrs (_: cfg: cfg ? snapshot) datasets);
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
}
