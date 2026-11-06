{ lib, ... }:
let
  # An ini file, so the password stays out of the Nix store:
  #   [admins]
  #   admin = <password>
  adminSecret = ../../secrets/couchdb-admin.age;
  # The dataset, route and status check need the couchdb user, which only exists once this is on.
  enabled = builtins.pathExists adminSecret;
  dataDir = "/var/lib/couchdb";
  port = 5984;
in
{
  # Holds the Obsidian vault for LiveSync. Hourly snapshots, plus the proton-backup copy.
  den.aspects.livesync.storage-datasets = lib.optionalAttrs enabled {
    "services/couchdb" = {
      mountpoint = dataDir;
      owner = "couchdb";
      group = "couchdb";
      mode = "0750";
      snapshot = "working";
      props = {
        recordsize = "128K";
        compression = "zstd";
      };
    };
  };

  den.aspects.livesync.service-routes = lib.optionalAttrs enabled {
    "notes-db.sk4rd.com" = {
      proxy = "reverse_proxy 127.0.0.1:${toString port}";
    };
  };

  den.aspects.livesync.status-endpoints = lib.optional enabled {
    name = "CouchDB";
    group = "Core";
    url = "http://127.0.0.1:${toString port}/_up";
    conditions = [ "[STATUS] == any(200, 401)" ];
  };

  den.aspects.livesync.nixos =
    { config, ... }:
    lib.mkMerge [
      {
        warnings = lib.optional (!enabled) ''
          livesync: secrets/couchdb-admin.age is missing (or not git-added), so
          CouchDB is disabled. Create it with `agenix -e couchdb-admin.age` in secrets/.
        '';
      }
      (lib.mkIf enabled {
        age.secrets.couchdb-admin = {
          file = adminSecret;
          owner = "couchdb";
        };

        services.couchdb = {
          enable = true;
          bindAddress = "127.0.0.1";
          inherit port;
          extraConfigFiles = [ config.age.secrets.couchdb-admin.path ];
          # Same values as LiveSync's utils/couchdb/provision.ts.
          extraConfig = {
            couchdb = {
              single_node = "true";
              max_document_size = "50000000";
            };
            cluster.n = "1";
            chttpd = {
              require_valid_user = "true";
              enable_cors = "true";
              max_http_request_size = "4294967296";
            };
            chttpd_auth.require_valid_user = "true";
            httpd = {
              WWW-Authenticate = ''Basic realm="couchdb"'';
              enable_cors = "true";
            };
            cors = {
              credentials = "true";
              origins = "app://obsidian.md,capacitor://localhost,http://localhost";
            };
          };
        };

        systemd.services.couchdb = {
          after = [ "zfs-datasets.service" ];
          requires = [ "zfs-datasets.service" ];
          unitConfig.AssertPathIsMountPoint = dataDir;
        };
      })
    ];
}
