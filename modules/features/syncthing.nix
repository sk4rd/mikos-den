{ den, lib, ... }:

let
  hubDir = "/var/lib/syncthing";

  port = 22000;
  hubHost = "nas";

  ignoreAll = [
    "(?d)node_modules"
    "(?d)target"
    "(?d).direnv"
    "(?d).venv"
    "(?d)__pycache__"
    "(?d).zig-cache"
    "(?d)result"
    "(?d)result-*"
    "**/.git/**.lock"
  ];
  ignores = {
    downloads = [
      "*.part"
      "*.crdownload"
    ];
  };
  stignore = id: lib.concatLines (ignoreAll ++ ignores.${id} or [ ]);

  deviceIds = {
    nas = "6BVSSKY-OSQXLMA-POYURPA-5RLO5MO-EHOLNGM-DTZ4VHL-3GFWRG7-USW4KQD";
    workstation = "43MXGXQ-X7MXUOZ-PMYLTDS-2NRUG47-QL3VV67-NRCX7JV-DVNRXVH-IKEL5QB";
    thinkpad-z13 = "RU64LCY-SQ6MTMX-6IXHXNY-P43DG6G-MUD3PTG-44QMSEK-SENVXAF-XGJWIQV";
  };

  common =
    {
      config,
      name,
      devices,
      folders,
    }:
    {
      age.secrets."syncthing-${name}-key".file = ../../secrets/syncthing-${name}-key.age;

      services.syncthing = {
        enable = true;
        cert = "${../../dots/syncthing + "/${name}-cert.pem"}";
        key = config.age.secrets."syncthing-${name}-key".path;
        settings = {
          inherit devices;
          # Conflict copies are off on purpose: a lost edit comes back from the hub's ZFS snapshots
          # or the restic backup.
          folders = lib.mapAttrs (_: f: f // { maxConflicts = 0; }) folders;

          options = {
            listenAddresses = [ "tcp://0.0.0.0:${toString port}" ];
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            relaysEnabled = false;
            natEnabled = false;
            urAccepted = -1;
          };
        };
      };
    };
in
{
  den.aspects = {
    syncthing = {
      settings.folders = lib.mkOption {
        type = lib.types.attrsOf (lib.types.strMatching "[^/].*");
        default = {
          desktop = "Desktop";
          documents = "Documents";
          downloads = "Downloads";
          music = "Music";
          pictures = "Pictures";
          videos = "Videos";
          projects = "Projects";
          learnharness = ".config/LearnHarness/data";
        };
        description = "Folders to sync through the NAS: folder ID to path relative to the home directory";
      };

      hjem =
        { host, ... }:
        let
          inherit (host.settings.syncthing) folders;
        in
        {
          files = lib.mapAttrs' (
            id: path:
            lib.nameValuePair "${path}/.stignore" {
              text = stignore id;
            }
          ) folders;
        };

      nixos =
        {
          config,
          host,
          ...
        }:
        let
          home = config.users.users.miko.home;
          network = import ../../lib/network.nix;
        in
        lib.mkMerge [
          (common {
            inherit config;
            inherit (host) name;
            folders = lib.mapAttrs (_: path: {
              path = "${home}/${path}";
              devices = [ hubHost ];
            }) host.settings.syncthing.folders;
            devices.${hubHost} = {
              id = deviceIds.${hubHost};
              addresses = [ "tcp://${hubHost}:${toString port}" ];
            };
          })
          {
            services.syncthing = {
              user = "miko";
              group = "users";
              dataDir = home;
            };
            # Proton's exclusive DNS drops the LAN resolver; pin the reachable hub.
            networking.hosts.${network.nasLanAddress} = [ hubHost ];
          }
        ];
    };

    syncthing-hub.storage-datasets."services/syncthing" = {
      mountpoint = hubDir;
      owner = "syncthing";
      group = "syncthing";
      mode = "0750";
      snapshot = "working";
      props = {
        recordsize = "128K";
        compression = "zstd";
      };
    };

    syncthing-hub.nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        clients = removeAttrs deviceIds [ host.name ];
        clientFolders = lib.mapAttrs (
          client: _: den.hosts.x86_64-linux.${client}.settings.syncthing.folders
        ) clients;
        folderIds = lib.unique (lib.concatMap lib.attrNames (lib.attrValues clientFolders));
      in
      lib.mkMerge [
        (common {
          inherit config;
          inherit (host) name;
          devices = lib.mapAttrs (_: id: { inherit id; }) clients;
          folders = lib.genAttrs folderIds (id: {
            path = "${hubDir}/${id}";
            devices = lib.attrNames (lib.filterAttrs (_: f: f ? ${id}) clientFolders);
          });
        })
        {
          services.syncthing = {
            dataDir = hubDir;
            # The module creates only the last level with the service's owner.
            configDir = "${hubDir}/config";
          };

          networking.firewall.allowedTCPPorts = [ port ];

          systemd.services.syncthing = {
            after = [ "zfs-datasets.service" ];
            requires = [ "zfs-datasets.service" ];
            unitConfig.AssertPathIsMountPoint = hubDir;
            # The hub ignores what the clients ignore, so it doesn't keep offering
            # files a client stopped sending, and they stay out of the backup.
            preStart = lib.concatMapStrings (id: ''
              install -D -m 0644 ${pkgs.writeText "stignore-${id}" (stignore id)} ${hubDir}/${id}/.stignore
            '') folderIds;
          };
        }
      ];
  };
}
