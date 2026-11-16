{ lib, ... }:

let
  octet = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])";
  ipv4 = lib.types.strMatching "${octet}\\.${octet}\\.${octet}\\.${octet}";
in
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
              address = lib.mkOption { type = ipv4; };
              hostname = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              reachPeers = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Other peer hostnames this peer may open connections to over the tunnel, on all ports";
              };
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

        serverAddress = lib.head (lib.splitString "/" cfg.address);

        peerRule =
          chain: peer: rule:
          "iptables -w -I ${chain} 1 -i wg0 -s ${peer.address}/32 ${rule}";

        # Replies pass through the NAT module's ESTABLISHED,RELATED rule, which sits above the
        # appended drops.
        forwardRules =
          map (peer: peerRule "nixos-filter-forward" peer "-o ${cfg.wanInterface} -j ACCEPT") cfg.peers
          ++ lib.concatMap (
            peer:
            map (target: peerRule "nixos-filter-forward" peer "-o wg0 -d ${target.address}/32 -j ACCEPT") (
              lib.filter (target: lib.elem target.hostname peer.reachPeers) cfg.peers
            )
          ) cfg.peers
          ++ [
            "iptables -w -A nixos-filter-forward -i wg0 -j DROP"
            "iptables -w -A nixos-filter-forward -o wg0 -j DROP"
          ];

        natRules = map (
          peer:
          "iptables -w -t nat -A nixos-nat-post -s ${peer.address}/32 -o ${cfg.wanInterface} -j MASQUERADE"
        ) cfg.peers;
      in
      {
        networking = {
          wireguard.interfaces.wg0 = {
            ips = [ cfg.address ];
            listenPort = cfg.port;
            privateKeyFile = config.age.secrets.wg-server-key.path;
            peers = map (peer: {
              inherit (peer) publicKey;
              allowedIPs = [ "${peer.address}/32" ];
            }) cfg.peers;
          };

          hosts = lib.mkMerge [
            (lib.listToAttrs (
              lib.concatMap (
                peer:
                lib.optional (peer.hostname != null) {
                  name = peer.hostname;
                  value = [ peer.address ];
                }
              ) cfg.peers
            ))
            # The tunnel address is in no DNS zone, so the NAS's own name needs pinning too.
            { ${host.name} = [ serverAddress ]; }
          ];

          firewall = {
            allowedUDPPorts = [ cfg.port ];
            trustedInterfaces = [ "wg0" ];
          };

          # The NAT module's own rules would let every wg0 peer reach the LAN, so it gets no
          # internal interfaces; the rules below forward and masquerade per peer instead.
          nat = {
            enable = true;
            internalInterfaces = [ ];
            externalInterface = cfg.wanInterface;
            extraCommands = ''
              ${lib.concatStringsSep "\n" forwardRules}
              ${lib.concatStringsSep "\n" natRules}
            '';
          };
        };

        age.secrets.wg-server-key.file = ../../secrets/wg-server-key.age;

        systemd.services.wireguard-wg0.restartTriggers = [
          (builtins.hashFile "sha256" ../../secrets/wg-server-key.age)
        ];
      };
  };
}
