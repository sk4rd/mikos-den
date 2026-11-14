{ lib, den, ... }:

let
  network = import ../../lib/network.nix;

  nasPublicKey = "gEhN/FkLUEKlbjfu2Vixc4iTM3d6abuQWAMGdxORRSo=";
  endpointHost = "vpn.sk4rd.com";
  endpointPort = "51820";
  endpoint = "${endpointHost}:${endpointPort}";
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
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.nas-vpn-client;


        # NetworkManager resolves the endpoint only on activation; refresh a changed IP.
        endpointUpdater = pkgs.writeShellApplication {
          name = "nas-vpn-endpoint";
          inheritPath = false;
          runtimeInputs = [
            pkgs.wireguard-tools
            pkgs.gawk
            pkgs.getent
          ];
          text = ''
            [ -d /sys/class/net/wg-nas ] || exit 0

            # Offline lookups are expected and leave the current endpoint alone.
            resolved=$(getent ahostsv4 ${lib.escapeShellArg endpointHost} 2>/dev/null) || exit 0
            addr=$(awk 'NR == 1 { print $1 }' <<< "$resolved")
            [ -n "$addr" ] || exit 0

            current=$(wg show wg-nas endpoints | awk -v key=${lib.escapeShellArg nasPublicKey} '$1 == key { print $2 }')
            [ "$current" = "$addr:${endpointPort}" ] && exit 0

            wg set wg-nas peer ${lib.escapeShellArg nasPublicKey} endpoint "$addr:${endpointPort}"
          '';
        };
      in
      {
        age.secrets.${cfg.secret}.file = ../../secrets/${cfg.secret}.age;

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [
            config.age.secrets.${cfg.secret}.path
          ];

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
              inherit endpoint;
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

        systemd.services.nas-vpn-endpoint = {
          description = "Point the nas WireGuard tunnel at the current address of ${endpointHost}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe endpointUpdater;
          };
        };

        systemd.timers.nas-vpn-endpoint = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "2min";
            Unit = "nas-vpn-endpoint.service";
          };
        };
      };
  };
}
