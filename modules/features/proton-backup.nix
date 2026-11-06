{ lib, ... }:
let
  repo = "/tank/backups/restic";
  passwordSecret = ../../secrets/restic-password.age;
  # Folder in Proton Drive that receives the mirrored restic repository
  # (Proton paths start at /my-files; created by the upload if missing).
  remoteParent = "/my-files/Backups/nas";
  stateDir = "/var/lib/proton-backup";
in
{
  den.aspects.proton-backup.status-heartbeats =
    lib.optionalAttrs (builtins.pathExists passwordSecret)
      {
        notes-backup = {
          name = "Notes restic backup";
          group = "Backups";
          unit = "restic-backups-notes.service";
          interval = "25h";
        };
        notes-upload = {
          name = "Notes Proton Drive copy";
          group = "Backups";
          unit = "proton-backup-upload.service";
          interval = "25h";
        };
        notes-check = {
          name = "Notes repository integrity";
          group = "Backups";
          unit = "restic-check-notes.service";
          interval = "169h";
        };
      };

  den.aspects.proton-backup.storage-datasets = {
    "backups/restic" = {
      mountpoint = repo;
      owner = "root";
      group = "root";
      mode = "0700";
      props.compression = "off"; # restic packs are already compressed and encrypted
    };
  };

  den.aspects.proton-backup.nixos =
    { config, pkgs, ... }:
    let
      proton-drive = pkgs.proton-drive-cli;
      protonEnv = {
        # Headless: session kept in a 0600 file under stateDir instead of a keyring.
        PROTON_DRIVE_CREDENTIALS_STORE = "unsafe_file";
        PROTON_DRIVE_CACHE_DIR = stateDir;
        PROTON_DRIVE_LOG_LEVEL = "INFO";
      };

      # One-time interactive sign-in on the NAS: `sudo proton-backup-login`.
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

      # Uploads never delete: pruned packs stay in Proton Drive, which keeps the
      # remote copy a consistent (if larger) restic repository. Locks are not uploaded.
      upload = pkgs.writeShellApplication {
        name = "proton-backup-upload";
        runtimeInputs = [
          proton-drive
          pkgs.findutils
          pkgs.coreutils
          pkgs.gnugrep
        ];
        text = ''
          # Create the remote folders one level at a time if they don't exist.
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

          # Verify: the newest local snapshot must now exist in Proton Drive.
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
    in
    lib.mkMerge [
      # Always available: the Proton sign-in doesn't need the restic password.
      {
        environment.systemPackages = [
          login
          pkgs.restic
        ];
        warnings = lib.optional (!builtins.pathExists passwordSecret) ''
          proton-backup: secrets/restic-password.age is missing (or not git-added),
          so the notes backup, Proton upload and their Gatus checks are disabled.
          Create it with `agenix -e restic-password.age` in secrets/.
        '';
      }
      (lib.mkIf (builtins.pathExists passwordSecret) {
        age.secrets.restic-password.file = passwordSecret;

        services.restic.backups.notes = {
          repository = repo;
          passwordFile = config.age.secrets.restic-password.path;
          initialize = true;
          # LiveSync's CouchDB: the vault stays end-to-end encrypted in here, and its files are
          # append-only, so copying them while it runs is safe.
          paths = [ "/var/lib/couchdb" ];
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

        systemd.services.restic-backups-notes.unitConfig = lib.mkMerge [
          (onResult "notes-backup")
          { OnSuccess = [ "proton-backup-upload.service" ]; }
        ];

        # Weekly: verify the repository structure and read back 10% of the data.
        systemd.services.restic-check-notes = {
          description = "Check the notes restic repository";
          environment = {
            RESTIC_REPOSITORY = repo;
            RESTIC_PASSWORD_FILE = config.age.secrets.restic-password.path;
            RESTIC_CACHE_DIR = "/var/cache/restic-check-notes";
          };
          unitConfig = onResult "notes-check";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe pkgs.restic} check --read-data-subset=10%";
            CacheDirectory = "restic-check-notes";
          };
        };
        systemd.timers.restic-check-notes = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "Sun 05:00";
            Persistent = true;
          };
        };

        systemd.services.proton-backup-upload = {
          description = "Mirror the restic repository to Proton Drive";
          unitConfig = onResult "notes-upload";
          environment = protonEnv;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe upload;
            StateDirectory = "proton-backup";
            StateDirectoryMode = "0700";
          };
        };
      })
    ];
}
