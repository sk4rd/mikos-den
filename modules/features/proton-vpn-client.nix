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
        network = import ../../lib/network.nix;

        endpointParts = lib.splitString ":" cfg.endpoint;
        endpointHost = lib.head endpointParts;
        endpointPort = lib.elemAt endpointParts 1;

        # Own table, so the NixOS firewall is untouched. Loaded when wg-proton comes up
        # and kept until the kill switch is toggled off.
        killswitchRules = ''
          table inet proton-killswitch {
            chain output {
              type filter hook output priority 0; policy drop;

              oifname "lo" accept
              oifname "wg-proton" accept
              ip daddr ${network.lanPrefix} accept
              udp dport 67-68 accept
              ip daddr ${endpointHost} udp dport ${endpointPort} accept
              ct state established,related accept
            }
          }
        '';

        rulesFile = pkgs.writeText "proton-killswitch.nft" killswitchRules;
        nft = lib.getExe pkgs.nftables;
        systemctl = lib.getExe' config.systemd.package "systemctl";

        # Arms the kill switch when the tunnel comes up. There is deliberately no
        # `down` branch: only the toggle (or `systemctl stop`) disarms it, so a
        # dropped tunnel cannot leak.
        arm = pkgs.writeShellApplication {
          name = "proton-killswitch-arm";
          inheritPath = false;
          text = ''
            if [ "''${2:-}" = up ] && [ "''${CONNECTION_ID:-}" = proton-vpn ]; then
              ${systemctl} start --no-block proton-killswitch.service
            fi
          '';
        };

        toggle = pkgs.writeShellApplication {
          name = "proton-killswitch-toggle";
          inheritPath = false;
          runtimeInputs = [
            pkgs.libnotify
            pkgs.networkmanager
          ];
          text = ''
            if ${systemctl} is-active --quiet proton-killswitch.service; then
              ${systemctl} stop proton-killswitch.service
              notify-send --icon=shield-off "Kill switch off" "Traffic is no longer restricted."
            else
              # Armed first, so there is no window without it. The table allows the
              # tunnel's own UDP, so the connection can still come up.
              ${systemctl} start proton-killswitch.service
              # Re-arming while connected must not restart the tunnel.
              if [ -d /sys/class/net/wg-proton ] || nmcli --wait 20 connection up proton-vpn; then
                notify-send --icon=shield-lock "Kill switch on" "Connected to Proton VPN."
              else
                notify-send --urgency=critical --icon=shield-lock "Kill switch on" "Proton VPN did not connect. Traffic stays blocked until you turn it off."
              fi
            fi
          '';
        };
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
        # Not wanted by any target: the tunnel coming up (or the toggle) starts it, and
        # it does not return after a reboot.
        systemd.services.proton-killswitch = {
          description = "Proton VPN kill switch";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${nft} -f ${rulesFile}";
            ExecStop = "-${nft} delete table inet proton-killswitch";
          };
        };

        networking.networkmanager.dispatcherScripts = [
          {
            source = lib.getExe arm;
            type = "basic";
          }
        ];

        # The toggle runs as the logged-in user. Let wheel start and stop this one unit.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "proton-killswitch.service" &&
                subject.isInGroup("wheel")) {
              return polkit.Result.YES;
            }
          });
        '';

        environment.systemPackages = [ toggle ];
      };
  };
}
