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

    hjem =
      { pkgs, ... }:
      let
        # One animation serves every scratchpad window, so it slides each window off whichever side
        # edge of the output it is nearer. umbriel_output_rect comes from the Umbriel fork in
        # flake.nix. uv spans the window alone; this reads as a slide off the screen edge because
        # both windows sit against one.
        slideIn = pkgs.writeText "slide-in.glsl" ''
          vec4 animation(vec2 uv) {
            float visible = umbriel_direction > 0.0 ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
            bool left = umbriel_output_rect.x + umbriel_output_rect.z * 0.5 < 0.5;
            vec2 from = vec2(left ? uv.x + 1.0 - visible : uv.x - 1.0 + visible, uv.y);
            return from.x < 0.0 || from.x > 1.0 ? vec4(0.0) : umbriel_sample(from);
          }
        '';
      in
      {
        packages = with pkgs; [
          ghostty
          (writeShellApplication {
            name = "side-toggle";
            runtimeInputs = [
              ghostty
              jq
            ];
            text = builtins.readFile ./side-toggle.sh;
          })
        ];

        files = {
          ".config/ghostty/themes/${theme.name}".text = ghosttyTheme;

          ".config/ghostty/keybinds".source = ../../dots/ghostty/keybinds;

          # The "side" pad also holds the Claude window from ai.nix.
          ".config/umbriel/conf.d/terminal-scratch.toml".text = ''
            [keybinds]
            "Mod+T" = { action = "spawn side-toggle den.terminal", repeat = false }

            [[scratchpad]]
            name = "side"

            [[window_rule]]
            match.app_id = "^den.terminal$"
            default_scratchpad = "side"
            default_floating_size = { width = 0.4, height = 1.0 }
            default_position = { x = 0, y = 0, anchor = "right" }
            border_width = 0
            corner_radius = 0

            [animation.scratchpad]
            dim = 0.0
            effect = "slide-in"

            [effects.preset.slide-in]
            kind = "animation"
            shader = "${slideIn}"
          '';

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
