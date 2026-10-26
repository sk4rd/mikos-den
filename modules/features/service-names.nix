{ lib, ... }:

let
  domain = "sk4rd.com";
in
{
  den.quirks.service-routes.description = "Reverse-proxy routes contributed by services";

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

        virtualHosts = lib.mapAttrs (_: proxy: {
          extraConfig = ''
            tls {
              dns cloudflare {file.${config.age.secrets.cloudflare-dns-token.path}}
            }
            ${proxy}
          '';
        }) routes;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };
}
