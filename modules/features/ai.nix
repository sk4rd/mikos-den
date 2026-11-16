{ den, ... }:

{
  den.aspects.ai = {
    includes = [
      (den.batteries.unfree [ "claude-code" ])
    ];

    # Agents install prebuilt binaries on the fly (uv wheels, npm packages).
    nixos.programs.nix-ld.enable = true;

    # ~/.claude/settings.json is rewritten by Claude Code and other tools, so it cannot come from
    # the store.
    nixos.environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "bash ${./claude-statusline.sh}";
      };
      hooks = {
        WorktreeCreate = [
          {
            hooks = [
              {
                type = "command";
                command = "bash ${./claude-worktree.sh} create";
              }
            ];
          }
        ];
        WorktreeRemove = [
          {
            hooks = [
              {
                type = "command";
                command = "bash ${./claude-worktree.sh} remove";
              }
            ];
          }
        ];
      };
    };

    hjem =
      { pkgs, ... }:
      let
        # uv spans only the window, so this reads as a slide off the screen edge
        # only while the window sits against the left edge.
        slideLeft = pkgs.writeText "slide-left.glsl" ''
          vec4 animation(vec2 uv) {
            float visible = umbriel_direction > 0.0 ? umbriel_clamped_progress : 1.0 - umbriel_clamped_progress;
            vec2 from = vec2(uv.x + 1.0 - visible, uv.y);
            return from.x > 1.0 ? vec4(0.0) : umbriel_sample(from);
          }
        '';
      in
      {
        files.".config/umbriel/conf.d/claude-scratch.toml".text = ''
          [keybinds]
          "Mod+C" = { action = "scratchpad-toggle claude", repeat = false }

          [[scratchpad]]
          name = "claude"
          spawn_when_empty = "ghostty --class=den.claude --working-directory=home -e claude"

          [[window_rule]]
          match.app_id = "^den.claude$"
          default_scratchpad = "claude"
          default_floating_size = { width = 0.4, height = 1.0 }
          default_position = { x = 0, y = 0, anchor = "left" }
          border_width = 0
          corner_radius = 0

          [animation.scratchpad]
          dim = 0.0
          effect = "slide-left"

          [effects.preset.slide-left]
          kind = "animation"
          shader = "${slideLeft}"
        '';

        packages = with pkgs; [
          claude-code
          opencode

          git
          gh
          ripgrep
          fd
          file
          tree
          jq
          yq-go
          sqlite
          curl
          wget
          unzip
          zip
          python3
          uv
          nodejs
        ];

        files.".claude/CLAUDE.md" = {
          source = ../../dots/claude/CLAUDE.md;
          clobber = true;
        };

        # uv would otherwise download its own Python builds, which only run through nix-ld.
        environment.sessionVariables = {
          UV_PYTHON = "${pkgs.python3}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
        };
      };
  };
}
