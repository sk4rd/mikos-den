{ den, ... }:

{
  den.aspects.media-vpn-health.includes = [ den.aspects.media-downloads ];

  den.aspects.media-vpn-health.status-endpoints = [
    {
      name = "Proton VPN";
      group = "VPN";
      url = "http://127.0.0.1:9188/health";
      conditions = [
        "[STATUS] == 200"
        "[BODY].ok == true"
      ];
    }
  ];

  den.aspects.media-vpn-health.nixos =
    { pkgs, lib, ... }:
    let
      # Proves torrent traffic is behind the tunnel, not just that the units run: the namespace's public IP
      # must differ from the host's, and DNS and the listener are checked from inside qBittorrent.
      healthScript = pkgs.writeShellScript "media-vpn-health" ''
        export PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              gawk
              glibc.getent
              gnugrep
              gnused
              iproute2
              jq
              systemd
              util-linux
              wireguard-tools
              zfs
            ]
          )
        }:${pkgs.zfs}/sbin"
        ${builtins.readFile ./media-vpn-health-check.sh}
      '';

      healthServer = pkgs.writeText "media-vpn-health-server.py" (
        builtins.readFile ./media-vpn-health-server.py
      );
    in
    {
      systemd.tmpfiles.rules = [
        "d /run/media-vpn-health 0755 root root -"
      ];

      systemd.services.media-vpn-health = {
        description = "Check the Proton VPN namespace and qBittorrent";
        after = [
          "media-vpn.service"
          "qbittorrent.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = healthScript;
        };
      };

      systemd.timers.media-vpn-health = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "60s";
          AccuracySec = "5s";
          Unit = "media-vpn-health.service";
        };
      };

      # Results older than 180s count as failed, so a stopped timer reads as down rather than stale.
      systemd.services.media-vpn-health-http = {
        description = "Serve media VPN health status";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${healthServer}";
          DynamicUser = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
}
