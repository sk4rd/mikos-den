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
    provides.to-hosts.nixos = { pkgs, ... }: {
      environment.sessionVariables.TERMINAL = "${pkgs.ghostty}/bin/ghostty";
    };

    hjem = { pkgs, ... }: {
      packages = with pkgs; [ ghostty ];

      files.".config/ghostty/themes/${theme.name}".text = ghosttyTheme;

      files.".config/ghostty/keybinds".source = ../../dots/ghostty/keybinds;

      files.".config/ghostty/config.ghostty".text = ''
        theme = ${theme.name}
        font-family = ${theme.fonts.mono.name}
        font-size = ${toString theme.fonts.mono.size}
        shell-integration = fish

        # Vim-style pane control. A config-file path resolves relative to the
        # file holding the directive, which here is a store path, so name it
        # with ~ instead.
        config-file = ~/.config/ghostty/keybinds
      '';
    };
  };
}
