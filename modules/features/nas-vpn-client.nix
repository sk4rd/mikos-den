{ lib, den, ... }:

let
  network = import ../../lib/network.nix;

  nasPublicKey = "gEhN/FkLUEKlbjfu2Vixc4iTM3d6abuQWAMGdxORRSo=";
in
{
  den.aspects.nas-vpn-client = {
    includes = [ den.aspects.secrets ];

    settings = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "WireGuard address of this client";
      };

      secret = lib.mkOption {
        type = lib.types.str;
        description = "Name of the agenix environment file containing WG_PRIVATE_KEY";
      };
    };

    nixos =
      { config, host, ... }:
      let
        cfg = host.settings.nas-vpn-client;
      in
      {
        age.secrets.${cfg.secret}.file = ../../secrets/${cfg.secret}.age;

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.age.secrets.${cfg.secret}.path ];

          profiles.nas-vpn = {
            connection = {
              id = "nas-vpn";
              type = "wireguard";
              interface-name = "wg-nas";
              autoconnect = true;
            };

            wireguard = {
              private-key = "$WG_PRIVATE_KEY";
              fwmark = 51821;
            };

            "wireguard-peer.${nasPublicKey}" = {
              endpoint = "vpn.sk4rd.com:51820";
              allowed-ips = "10.100.0.0/24;${network.lanPrefix};";
              persistent-keepalive = 25;
            };

            # Split tunnel: only the LAN and VPN ranges use it, and they are IPv4 only.
            ipv4 = {
              method = "manual";
              addresses = cfg.address;
              never-default = true;
              dns = network.routerAddress;
              # Above ethernet (100) and Wi-Fi (600), so the direct LAN route wins at home.
              route-metric = 700;
            };

            ipv6.method = "disabled";
          };
        };
      };
  };
}
