{ ... }:

{
  den.aspects.flaresolverr.nixos = {
    services.flaresolverr = {
      enable = true;
      openFirewall = false;
    };
    systemd.services.flaresolverr.environment.HOST = "127.0.0.1";
  };
}
