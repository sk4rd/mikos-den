{ lib, ... }:

let
  domain = "sk4rd.com";

  proxies = {
    "ha.${domain}" = "reverse_proxy 127.0.0.1:8123";
  };
in
{
  den.aspects.service-names.nixos =
    { config, pkgs, ... }:
    {
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
        }) proxies;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };
}
