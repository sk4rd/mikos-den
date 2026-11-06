{ lib, ... }:

{
  den.aspects.proton-vpn-client = {
    settings = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "Public key of the ProtonVPN WireGuard server";
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        description = "Endpoint of the ProtonVPN WireGuard server";
      };

      secret = lib.mkOption {
        type = lib.types.str;
        description = "Name of the agenix environment file containing PROTONVPN_PRIVATE_KEY";
      };
    };

    nixos =
      {
        config,
        host,
        ...
      }:
      let
        cfg = host.settings.proton-vpn-client;
      in
      {
        age.secrets.${cfg.secret}.file = ../../secrets/${cfg.secret}.age;

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.age.secrets.${cfg.secret}.path ];

          profiles.proton-vpn = {
            connection = {
              id = "proton-vpn";
              type = "wireguard";
              interface-name = "wg-proton";
              # Routes all traffic, so it's switched on by hand.
              autoconnect = false;
            };

            wireguard.private-key = "$PROTONVPN_PRIVATE_KEY";

            "wireguard-peer.${cfg.publicKey}" = {
              endpoint = cfg.endpoint;
              allowed-ips = "0.0.0.0/0;::/0;";
              persistent-keepalive = 25;
            };

            # A negative priority makes NetworkManager drop other DNS while connected, so lookups can't leak.
            ipv4 = {
              method = "manual";
              address1 = "10.2.0.2/32";
              dns = "10.2.0.1";
              dns-priority = -50;
            };

            ipv6 = {
              method = "manual";
              address1 = "2a07:b944::2:2/128";
              dns = "2a07:b944::2:1";
              dns-priority = -50;
            };
          };
        };
      };
  };
}
