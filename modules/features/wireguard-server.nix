{ lib, den, ... }:

{
  den.aspects.wireguard-server = {
    settings = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "10.100.0.1/24";
        description = "WireGuard address of the server";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 51820;
        description = "WireGuard listen port";
      };

      wanInterface = lib.mkOption {
        type = lib.types.str;
        description = "WAN interface used for NAT";
      };

      peers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              publicKey = lib.mkOption { type = lib.types.str; };
              allowedIPs = lib.mkOption { type = lib.types.listOf lib.types.str; };
            };
          }
        );
        default = [ ];
        description = "WireGuard peers allowed to connect";
      };
    };

    nixos =
      { config, host, ... }:
      let
        cfg = host.settings.wireguard-server;
      in
      {
        age.secrets.wg-server-key.file = ../../secrets/wg-server-key.age;

        networking.wireguard.interfaces.wg0 = {
          ips = [ cfg.address ];
          listenPort = cfg.port;
          privateKeyFile = config.age.secrets.wg-server-key.path;
          peers = map (peer: { inherit (peer) publicKey allowedIPs; }) cfg.peers;
        };

        networking.firewall = {
          allowedUDPPorts = [ cfg.port ];
          # Peers are my own devices, so the tunnel skips the host firewall.
          trustedInterfaces = [ "wg0" ];
        };

        # The key file's path never changes, so a rotated key wouldn't restart the tunnel otherwise.
        systemd.services.wireguard-wg0.restartTriggers = [
          (builtins.hashFile "sha256" ../../secrets/wg-server-key.age)
        ];

        # Lets peers reach the LAN through the NAS.
        networking.nat = {
          enable = true;
          internalInterfaces = [ "wg0" ];
          externalInterface = cfg.wanInterface;
        };

        boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
      };
  };
}
