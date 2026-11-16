{ lib, ... }:
let
  repo = "/tank/backups/restic";
  passwordSecret = ../../secrets/restic-password.age;
  # Proton Drive paths start at /my-files.
  remoteParent = "/my-files/Backups/nas";
  stateDir = "/var/lib/proton-backup";

  snapshotName = "restic";
  sources = {
    "services/syncthing" = {
      mountpoint = "/var/lib/syncthing";
      # The device key is in agenix and the index rebuilds itself on restore.
      exclude = [
        "config"
        "index-*"
      ];
    };
    "services/couchdb" = {
      mountpoint = "/var/lib/couchdb";
      exclude = [ ];
    };
  };
  snapshotDir = src: "${src.mountpoint}/.zfs/snapshot/${snapshotName}";
in
{
  den.aspects.proton-backup = {
    status-heartbeats = lib.optionalAttrs (builtins.pathExists passwordSecret) {
      nas-backup = {
        name = "NAS restic backup";
        group = "Backups";
        unit = "restic-backups-nas.service";
        interval = "25h";
      };
      nas-upload = {
        name = "NAS Proton Drive copy";
        group = "Backups";
        unit = "proton-backup-upload.service";
        interval = "25h";
      };
      nas-check = {
        name = "NAS repository integrity";
        group = "Backups";
        unit = "restic-check-nas.service";
        interval = "169h";
      };
    };

    storage-datasets = {
      "backups/restic" = {
        mountpoint = repo;
        owner = "root";
        group = "root";
        mode = "0700";
        props.compression = "off";
      };
    };

    nixos =
      { config, pkgs, ... }:
      let
        proton-drive = pkgs.proton-drive-cli;
        zfs = lib.getExe' config.boot.zfs.package "zfs";
        snapshots = lib.mapAttrsToList (ds: _: "tank/${ds}@${snapshotName}") sources;
        dropSnapshots = lib.concatMapStringsSep "\n" (
          s: "${zfs} destroy ${s} 2>/dev/null || true"
        ) snapshots;

        protonEnv = {
          # The NAS is headless, so there is no keyring.
          PROTON_DRIVE_CREDENTIALS_STORE = "unsafe_file";
          PROTON_DRIVE_CACHE_DIR = stateDir;
          PROTON_DRIVE_LOG_LEVEL = "INFO";
        };

        login = pkgs.writeShellApplication {
          name = "proton-backup-login";
          runtimeInputs = [ proton-drive ];
          text = ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") protonEnv
            )}
            install -d -m 0700 ${stateDir}
            exec proton-drive auth login
          '';
        };

        # Nothing is deleted remotely: pruned packs pile up, and the copy stays a valid restic
        # repository.
        upload = pkgs.writeShellApplication {
          name = "proton-backup-upload";
          runtimeInputs = [
            proton-drive
            pkgs.findutils
            pkgs.coreutils
            pkgs.gnugrep
          ];
          text = ''
            parent=""
            IFS=/ read -ra parts <<<${lib.escapeShellArg remoteParent}
            for part in "''${parts[@]}"; do
              [[ -n $part ]] || continue
              if [[ -n $parent ]] && ! proton-drive filesystem list "$parent/$part" >/dev/null 2>&1; then
                proton-drive filesystem create-folder "$parent" "$part" >/dev/null
              fi
              parent="$parent/$part"
            done

            cd ${repo}
            mapfile -t items < <(find . -mindepth 1 -maxdepth 1 ! -name locks -printf '%f\n')
            proton-drive filesystem upload --file-conflict-strategy skip \
              --folder-conflict-strategy merge --skip-thumbnails \
              "''${items[@]}" ${lib.escapeShellArg remoteParent}

            latest=$(find snapshots -type f -printf '%T@ %f\n' | sort -n | tail -n1 | cut -d' ' -f2)
            [[ -n $latest ]] || { echo "no local snapshots" >&2; exit 1; }
            if ! proton-drive filesystem list ${lib.escapeShellArg "${remoteParent}/snapshots"} | grep -qF "$latest"; then
              echo "latest snapshot $latest missing in Proton Drive" >&2
              exit 1
            fi
            echo "Proton Drive has latest snapshot $latest"
          '';
        };

        onResult = id: {
          OnSuccess = [ "status-heartbeat@${id}.ok.service" ];
          OnFailure = [ "status-heartbeat@${id}.fail.service" ];
        };

        # With initialize = true, an unmounted repo would get a fresh restic init on the parent
        # dataset.
        mountGuards = paths: {
          after = [ "zfs-datasets.service" ];
          requires = [ "zfs-datasets.service" ];
          unitConfig.AssertPathIsMountPoint = paths;
        };
        sourceMounts = lib.mapAttrsToList (_: src: src.mountpoint) sources;
      in
      lib.mkMerge [
        {
          environment.systemPackages = [
            login
            pkgs.restic
          ];
          warnings = lib.optional (!builtins.pathExists passwordSecret) ''
            proton-backup: secrets/restic-password.age is missing (or not git-added),
            so the NAS backup, Proton upload and their Gatus checks are disabled.
            Create it with `agenix -e restic-password.age` in secrets/.
          '';
        }
        (lib.mkIf (builtins.pathExists passwordSecret) {
          age.secrets.restic-password.file = passwordSecret;

          services.restic.backups.nas = {
            repository = repo;
            passwordFile = config.age.secrets.restic-password.path;
            initialize = true;
            paths = lib.mapAttrsToList (_: snapshotDir) sources;
            exclude = lib.concatLists (
              lib.mapAttrsToList (_: src: map (p: "${snapshotDir src}/${p}") src.exclude) sources
            );
            # A failed run can leave the snapshots behind, so clear them first.
            backupPrepareCommand = ''
              ${dropSnapshots}
              ${zfs} snapshot ${lib.concatStringsSep " " snapshots}
            '';
            backupCleanupCommand = dropSnapshots;
            timerConfig = {
              OnCalendar = "03:00";
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
            pruneOpts = [
              "--keep-daily 14"
              "--keep-weekly 8"
              "--keep-monthly 24"
            ];
          };

          systemd = {
            services = {
              restic-backups-nas = lib.mkMerge [
                (mountGuards ([ repo ] ++ sourceMounts))
                {
                  unitConfig = lib.mkMerge [
                    (onResult "nas-backup")
                    { OnSuccess = [ "proton-backup-upload.service" ]; }
                  ];
                }
              ];

              restic-check-nas = lib.mkMerge [
                (mountGuards [ repo ])
                {
                  description = "Check the NAS restic repository";
                  environment = {
                    RESTIC_REPOSITORY = repo;
                    RESTIC_PASSWORD_FILE = config.age.secrets.restic-password.path;
                    RESTIC_CACHE_DIR = "/var/cache/restic-check-nas";
                  };
                  unitConfig = onResult "nas-check";
                  serviceConfig = {
                    Type = "oneshot";
                    ExecStart = "${lib.getExe pkgs.restic} check --read-data-subset=10%";
                    CacheDirectory = "restic-check-nas";
                  };
                }
              ];

              proton-backup-upload = lib.mkMerge [
                (mountGuards [ repo ])
                {
                  description = "Mirror the restic repository to Proton Drive";
                  unitConfig = onResult "nas-upload";
                  environment = protonEnv;
                  serviceConfig = {
                    Type = "oneshot";
                    ExecStart = lib.getExe upload;
                    StateDirectory = "proton-backup";
                    StateDirectoryMode = "0700";
                  };
                }
              ];
            };

            timers.restic-check-nas = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = "Sun 05:00";
                Persistent = true;
              };
            };
          };
        })
      ];
  };
}
