{ den, ... }:

{
  den.aspects.ai = {
    includes = [
      (den.batteries.unfree [ "claude-code" ])
      den.aspects.plannotator
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
    };

    hjem =
      { pkgs, ... }:
      {
        # side-toggle and the "side" scratchpad come from ghostty.nix. Claude Code never remembers trust for the home
        # directory, so a session started there asks every time.
        files.".config/umbriel/conf.d/claude-scratch.toml".text = ''
          [keybinds]
          "Mod+C" = { action = "spawn side-toggle den.claude --dir scratch claude", repeat = false }

          [[window_rule]]
          match.app_id = "^den.claude$"
          default_scratchpad = "side"
          default_floating_size = { width = 0.4, height = 1.0 }
          default_position = { x = 0, y = 0, anchor = "left" }
          border_width = 0
          corner_radius = 0
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
