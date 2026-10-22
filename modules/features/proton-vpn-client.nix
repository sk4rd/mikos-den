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
        pkgs,
        ...
      }:
      let
        cfg = host.settings.proton-vpn-client;
        endpoint = lib.splitString ":" cfg.endpoint;
        killSwitchRules = pkgs.writeText "proton-vpn-killswitch.nft" ''
          table inet proton_vpn_killswitch {
            chain output {
              type filter hook output priority 10; policy drop;

              oifname "lo" accept
              oifname "wg-proton" accept
              oifname "wg0" ip daddr 10.100.0.0/24 accept
              oifname "wg0" ip daddr 192.168.178.0/24 accept

              ip daddr ${builtins.elemAt endpoint 0} udp dport ${builtins.elemAt endpoint 1} accept
              meta mark 51821 udp dport 51820 accept

              udp sport 68 udp dport 67 accept
              udp sport 546 udp dport 547 accept
              icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } ip6 hoplimit 255 accept

              udp dport { 53, 853 } drop
              tcp dport { 53, 853 } drop
            }
          }
        '';
      in
      {
        age.secrets.${cfg.secret}.file = ../../secrets/${cfg.secret}.age;

        systemd.services.proton-vpn-killswitch = {
          description = "Block internet traffic outside ProtonVPN";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.nftables}/bin/nft -f ${killSwitchRules}";
            ExecStop = "${pkgs.nftables}/bin/nft delete table inet proton_vpn_killswitch";
          };
        };

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ config.age.secrets.${cfg.secret}.path ];

          profiles.proton-vpn = {
            connection = {
              id = "proton-vpn";
              type = "wireguard";
              interface-name = "wg-proton";
              autoconnect = false;
            };

            wireguard.private-key = "$PROTONVPN_PRIVATE_KEY";

            "wireguard-peer.${cfg.publicKey}" = {
              endpoint = cfg.endpoint;
              allowed-ips = "0.0.0.0/0;::/0;";
              persistent-keepalive = 25;
            };

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
