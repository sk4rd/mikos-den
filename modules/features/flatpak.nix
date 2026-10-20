{ den, ... }:

{
  den.aspects.flatpak.nixos = { pkgs, ... }: {
    services.flatpak.enable = true;

    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
    };
  };

  den.schema.host.includes = [ den.aspects.flatpak ];
}
