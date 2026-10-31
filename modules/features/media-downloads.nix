{ lib, den, ... }:

{
  den.aspects.media-downloads.includes = [
    den.aspects.media-storage
    den.aspects.secrets
  ];

  den.aspects.media-downloads.service-routes = {
    "qbittorrent.sk4rd.com" = {
      proxy = "reverse_proxy 10.200.0.2:8080";
    };
  };

  den.aspects.media-downloads.nixos = { config, pkgs, ... }: {
    age.secrets.proton-nas-key.file = ../../secrets/proton-nas-key.age;

    systemd.services.media-vpn = {
      description = "Isolated ProtonVPN network with a fail-closed firewall";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      restartTriggers = [ (builtins.hashFile "sha256" ../../secrets/proton-nas-key.age) ];
      path = [
        pkgs.iproute2
        pkgs.wireguard-tools
        pkgs.nftables
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = "private-key:${config.age.secrets.proton-nas-key.path}";
      };
      script = ''
        set -eu
        ip netns add media-vpn
        ip -n media-vpn link set lo up
        ip netns exec media-vpn nft -f - <<'EOF'
        table inet killswitch {
          chain input {
            type filter hook input priority 0; policy drop;
            iifname "lo" accept
            iifname "wg-media" tcp dport 8080 drop
            iifname "wg-media" accept
            ct state established,related accept
            iifname "media-ns" ip saddr 10.200.0.1 tcp dport 8080 accept
          }
          chain output {
            type filter hook output priority 0; policy drop;
            oifname "lo" accept
            oifname "wg-media" accept
            oifname "media-ns" ip daddr 10.200.0.1 tcp sport 8080 ct state established accept
          }
        }
        EOF
        ip link add media-host type veth peer name media-ns netns media-vpn
        ip address add 10.200.0.1/30 dev media-host
        ip link set media-host up
        ip -n media-vpn address add 10.200.0.2/30 dev media-ns
        ip -n media-vpn link set media-ns up
        # The WireGuard UDP socket stays in the host namespace; payload routing does not.
        ip link add wg-media type wireguard
        ip link set wg-media netns media-vpn
        ip netns exec media-vpn wg set wg-media \
          private-key "$CREDENTIALS_DIRECTORY/private-key" \
          peer 'OJv7H1H34Og2BqBwrUdTQPXZPD0oG1rh7wkMWAgGUAQ=' \
          endpoint 103.69.224.5:51820 allowed-ips 0.0.0.0/0 persistent-keepalive 25
        ip -n media-vpn address add 10.2.0.2/32 dev wg-media
        ip -n media-vpn link set wg-media mtu 1420 up
        ip -n media-vpn route add default dev wg-media
      '';
      postStop = ''
        ip link del wg-media 2>/dev/null || true
        ip link del media-host 2>/dev/null || true
        ip netns del media-vpn 2>/dev/null || true
      '';
    };

    services.qbittorrent = {
      enable = true;
      profileDir = "/var/lib/media-stack/qbittorrent";
      extraArgs = [ "--confirm-legal-notice" ];
    };
    users.users.qbittorrent.extraGroups = [ "media" ];

    systemd.services.qbittorrent-storage = {
      description = "Prepare qBittorrent state and downloads";
      after = [ "media-storage.service" ];
      requires = [ "media-storage.service" ];
      path = [ pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        install -d -m 0700 -o qbittorrent -g qbittorrent /var/lib/media-stack/qbittorrent
        install -d -m 2770 -o qbittorrent -g media /tank/data/media/downloads
        for dir in incomplete movies shows; do
          install -d -m 2770 -o qbittorrent -g media "/tank/data/media/downloads/$dir"
        done
      '';
    };

    systemd.services.qbittorrent = {
      after = [
        "qbittorrent-storage.service"
        "media-vpn.service"
      ];
      requires = [
        "qbittorrent-storage.service"
        "media-vpn.service"
      ];
      bindsTo = [ "media-vpn.service" ];
      partOf = [ "media-vpn.service" ];
      unitConfig.AssertPathIsMountPoint = [
        "/var/lib/media-stack"
        "/tank/data/media"
      ];
      preStart = ''
        ${pkgs.python3}/bin/python3 - <<'PY'
        import configparser
        from pathlib import Path
        path = Path("/var/lib/media-stack/qbittorrent/qBittorrent/config/qBittorrent.conf")
        cfg = configparser.ConfigParser(interpolation=None, strict=False)
        cfg.optionxform = str
        if path.exists():
            cfg.read(path)
        settings = {
            "BitTorrent": {
                "Session\\DefaultSavePath": "/tank/data/media/downloads",
                "Session\\TempPath": "/tank/data/media/downloads/incomplete",
                "Session\\TempPathEnabled": "true",
                "Session\\Interface": "wg-media",
            },
            "Preferences": {
                "WebUI\\Address": "10.200.0.2",
                "WebUI\\ServerDomains": '"qbittorrent.sk4rd.com;10.200.0.2"',
                "WebUI\\HostHeaderValidation": "true",
                "WebUI\\CSRFProtection": "true",
            },
        }
        for section, values in settings.items():
            if not cfg.has_section(section):
                cfg.add_section(section)
            for key, value in values.items():
                cfg.set(section, key, value)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w") as file:
            cfg.write(file, space_around_delimiters=False)
        path.chmod(0o600)
        PY
      '';
      serviceConfig = {
        NetworkNamespacePath = "/run/netns/media-vpn";
        BindReadOnlyPaths = [
          "${pkgs.writeText "media-vpn-resolv.conf" "nameserver 10.2.0.1\n"}:/etc/resolv.conf"
          "${pkgs.writeText "media-vpn-nsswitch.conf" "passwd: files\ngroup: files\nhosts: files dns\n"}:/etc/nsswitch.conf"
        ];
        # nscd's socket is host-wide and would resolve through the host network.
        TemporaryFileSystem = [ "/run/nscd" ];
        ProtectSystem = lib.mkForce "strict";
        ReadWritePaths = [
          "/var/lib/media-stack/qbittorrent"
          "/tank/data/media/downloads"
        ];
        UMask = "0002";
      };
    };
  };
}
