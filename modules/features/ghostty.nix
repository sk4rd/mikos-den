{ config, ... }:

let
  inherit (config) theme;
  c = theme.colors;

  ghosttyTheme = ''
    ${builtins.concatStringsSep "\n" (
      builtins.genList (i: "palette = ${toString i}=${builtins.elemAt theme.ansi i}") 16
    )}
    background = ${c.bg}
    foreground = ${c.fg}
    cursor-color = ${c.cursor}
    cursor-text = ${c.cursorText}
    selection-background = ${c.selection}
  '';
in
{
  den.aspects.ghostty = {
    provides.to-hosts.nixos = { lib, pkgs, ... }: {
      environment.sessionVariables.TERMINAL = "${pkgs.ghostty}/bin/ghostty";

      systemd.packages = [ pkgs.ghostty ];
      systemd.user.services."app-com.mitchellh.ghostty" = {
        wantedBy = [ "graphical-session.target" ];
        environment.PATH = lib.mkForce null;
      };
    };

    hjem = { pkgs, ... }: {
      packages = with pkgs; [ ghostty ];

      files = {
        ".config/ghostty/themes/${theme.name}".text = ghosttyTheme;

        ".config/ghostty/keybinds".source = ../../dots/ghostty/keybinds;

        ".config/ghostty/config.ghostty".text = ''
          theme = ${theme.name}
          font-family = ${theme.fonts.mono.name}
          font-size = ${toString theme.fonts.mono.size}
          shell-integration = fish
          config-file = ~/.config/ghostty/keybinds
        '';
      };
    };
  };
}
