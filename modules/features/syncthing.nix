{ lib, ... }:
let
  # Device IDs are created on first start. Pass 1: leave them null and deploy.
  # Pass 2: fill them in from `syncthing --device-id --home ~/.config/syncthing` on each host, then rebuild.
  devices = {
    nas = {
      id = null;
      # LAN for the workstation, WireGuard (wg0, trusted) for the thinkpad.
      addresses = [
        "tcp://192.168.178.3:22000"
        "quic://192.168.178.3:22000"
        "tcp://10.100.0.1:22000"
      ];
    };
    workstation = {
      id = null;
      addresses = [ "dynamic" ];
    };
    thinkpad-z13 = {
      id = null;
      addresses = [ "dynamic" ];
    };
  };

  # The NAS is the hub: every desktop syncs with it, desktops not with each other.
  hub = "nas";

  notesPath = host: if host == hub then "/tank/data/documents/notes" else "/home/miko/Notes";

  known = lib.filterAttrs (_: d: d.id != null) devices;
in
{
  den.aspects.syncthing.nixos =
    { config, ... }:
    let
      self = config.networking.hostName;
      isHub = self == hub;
      peers = lib.filterAttrs (name: _: name != self && (isHub || name == hub)) known;
    in
    {
      services.syncthing = {
        enable = true;
        user = "miko";
        group = "users";
        dataDir = "/home/miko";
        configDir = "/home/miko/.config/syncthing";
        # Only the hub accepts incoming connections; desktops dial it.
        openDefaultPorts = isHub;
        overrideDevices = true;
        overrideFolders = true;
        settings = {
          options = {
            # Private network only: no global discovery, no relays, no telemetry.
            globalAnnounceEnabled = false;
            relaysEnabled = false;
            natEnabled = false;
            localAnnounceEnabled = true;
            urAccepted = -1;
          };
          devices = lib.mapAttrs (name: d: {
            inherit (d) id addresses;
            inherit name;
          }) peers;
          folders.notes = {
            id = "notes";
            label = "Notes";
            path = notesPath self;
            devices = lib.attrNames peers;
            # Deleted/overwritten notes kept 30 days on the hub; ZFS snapshots on top.
            versioning = lib.mkIf isHub {
              type = "staggered";
              params.maxAge = toString (30 * 24 * 3600);
            };
          };
        };
      };

      systemd.tmpfiles.rules = lib.optional isHub "d /tank/data/documents/notes 0700 miko users -";
    };
}
