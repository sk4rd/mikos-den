{ lib, den, ... }:

let
  domain = "sk4rd.com";

  # Services that are not explicitly public stay reachable from the LAN and the VPN only.
  internalRanges = [
    "127.0.0.1/32"
    "::1/128"
    "192.168.178.0/24"
    "10.100.0.0/24"
  ];
in
{
  den.aspects.service-names.status-endpoints = [
    {
      name = "Caddy";
      group = "Core";
      url = "tcp://127.0.0.1:443";
      conditions = [ "[CONNECTED] == true" ];
    }
  ];

  den.aspects.service-names.nixos =
    {
      config,
      pkgs,
      service-routes,
      ...
    }:
    let
      routes = lib.foldl' (acc: entry: acc // entry) { } service-routes;
      names = lib.concatMap builtins.attrNames service-routes;

      virtualHosts = lib.mapAttrs (
        _: route:
        let
          guard = lib.optionalString (!(route.public or false)) ''
            @external not remote_ip ${lib.concatStringsSep " " internalRanges}
            respond @external 404
          '';
        in
        {
          extraConfig = ''
            tls {
              dns cloudflare {file.${config.age.secrets.cloudflare-dns-token.path}}
            }
            ${guard}
            ${route.proxy}
          '';
        }
      ) routes;
    in
    {
      age.secrets.cloudflare-dns-token = {
        file = ../../secrets/cloudflare-dns-token.age;
        owner = "caddy";
      };

      assertions = [
        {
          assertion = builtins.length names == builtins.length (lib.unique names);
          message = "Service route contributions must have unique hostnames";
        }
        {
          assertion = lib.all (route: builtins.isAttrs route && route ? proxy) (lib.attrValues routes);
          message = "Service route values must be { proxy = \"...\"; public = <bool>; }";
        }
      ];

      # Certs come from DNS-01, so nothing has to be reachable from outside.
      services.caddy = {
        enable = true;
        email = "admin@${domain}";

        # DNS-01 needs the Cloudflare provider, which upstream Caddy omits.
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
          hash = "sha256-5a5cpFl90pEWt0lUC4ZJQ7g+1//ZvsRhee64Dt9vh5o=";
        };

        inherit virtualHosts;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };
}
