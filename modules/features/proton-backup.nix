{ lib, ... }:
let
  repo = "/tank/backups/restic";
  passwordSecret = ../../secrets/restic-password.age;
  # Folder in Proton Drive that receives the mirrored restic repository
  # (Proton paths start at /my-files; created by the upload if missing).
  remoteParent = "/my-files/Backups/nas";
  stateDir = "/var/lib/proton-backup";

  # Gatus external endpoints (group "Backups"): each job pushes ok/fail, and a
  # missing push within the heartbeat interval alerts too (ntfy, like status.nix).
  heartbeatTokenFile = "/var/lib/backup-heartbeat/env";
  checks = {
    notes-backup = {
      name = "Notes restic backup";
      unit = "restic-backups-notes.service";
      interval = "25h";
    };
    notes-upload = {
      name = "Notes Proton Drive copy";
      unit = "proton-backup-upload.service";
      interval = "25h";
    };
    notes-check = {
      name = "Notes repository integrity";
      unit = "restic-check-notes.service";
      interval = "169h";
    };
  };
  # <group>_<name> with ' ', '/', '_', ',', '.', '#', '+', '&' replaced by '-'.
  gatusKey =
    name:
    "backups_"
    +
      lib.replaceStrings
        [
          " "
          "/"
          "_"
          ","
          "."
          "#"
          "+"
          "&"
        ]
        [
          "-"
          "-"
          "-"
          "-"
          "-"
          "-"
          "-"
          "-"
        ]
        (lib.toLower name);
in
{
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

      # backup-heartbeat <check>.<ok|fail>: push one result to Gatus.
      heartbeat = pkgs.writeShellApplication {
        name = "backup-heartbeat";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          check=''${1%.*} result=''${1##*.}
          case $check in
            ${
              lib.concatStrings (
                lib.mapAttrsToList (id: c: ''
                  ${id}) key=${gatusKey c.name} unit=${c.unit} ;;
                '') checks
              )
            }  *) echo "unknown check $check" >&2; exit 2 ;;
          esac
          # shellcheck source=/dev/null
          source ${heartbeatTokenFile}
          args=(--data-urlencode "success=$([[ $result == ok ]] && echo true || echo false)")
          [[ $result == ok ]] || args+=(--data-urlencode "error=$unit failed, see journalctl -u $unit")
          curl -fsS --retry 3 -X POST -G "''${args[@]}" \
            -H "Authorization: Bearer $BACKUP_HEARTBEAT_TOKEN" \
            "http://127.0.0.1:8081/api/v1/endpoints/$key/external"
        '';
      };

      onResult = id: {
        OnSuccess = [ "backup-heartbeat@${id}.ok.service" ];
        OnFailure = [ "backup-heartbeat@${id}.fail.service" ];
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
          paths = [ "/tank/data/documents/notes" ];
          exclude = [ ".stversions" ]; # Syncthing's own file versions
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

        systemd.services."backup-heartbeat@" = {
          description = "Report backup result %i to Gatus";
          after = [ "gatus.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe heartbeat} %i";
          };
        };

        # Random push token, created once; readable by root and gatus only.
        systemd.services.backup-heartbeat-token = {
          description = "Create the Gatus backup heartbeat token";
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
              printf 'BACKUP_HEARTBEAT_TOKEN=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${heartbeatTokenFile}
              chgrp gatus ${heartbeatTokenFile}
            fi
          '';
        };

        systemd.services.gatus = {
          requires = [ "backup-heartbeat-token.service" ];
          serviceConfig.EnvironmentFile = [ heartbeatTokenFile ];
        };

        services.gatus.settings.external-endpoints = lib.mapAttrsToList (_: c: {
          inherit (c) name;
          group = "Backups";
          token = "\${BACKUP_HEARTBEAT_TOKEN}";
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
        }) checks;

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
