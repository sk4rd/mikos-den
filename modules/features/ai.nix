{ den, inputs, ... }:

{
  den.aspects.ai.includes = [
    (den.batteries.unfree [ "claude-code" ])
  ];

  # Agents install tools on the fly (uv wheels, npm packages with prebuilt
  # binaries), and those expect a normal Linux loader. nix-ld provides one.
  den.aspects.ai.nixos.programs.nix-ld.enable = true;

  # Claude Code hooks of the walkthrough skill, for every host that has this
  # aspect. Claude Code reads /etc/claude-code/managed-settings.json in
  # addition to ~/.claude/settings.json, which it and other tools rewrite and
  # which can therefore not come from the store. The scripts are run from the
  # same input as the plugin and the skill, so all three stay in step.
  # See https://code.claude.com/docs/en/hooks and
  # https://code.claude.com/docs/en/settings (managed settings).
  den.aspects.ai.nixos.environment.etc."claude-code/managed-settings.json".text =
    let
      hooks = "${inputs.walkthrough-nvim}/skills/walkthrough/hooks";
    in
    builtins.toJSON {
      hooks = {
        # Leaving plan mode: the plan opens in Neovim and Claude waits for
        # approve or feedback. Without a reachable Neovim the script exits
        # silently and Claude's own prompt appears. The timeout is a day,
        # because a plan may wait for a long time.
        PermissionRequest = [
          {
            matcher = "ExitPlanMode";
            hooks = [
              {
                type = "command";
                command = "${hooks}/plan-review.sh";
                timeout = 86400;
              }
            ];
          }
        ];
        # In a session that uses the skill, tell Claude on every prompt
        # whether a Neovim with the plugin is reachable.
        UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = "${hooks}/visual-mode.sh";
                timeout = 10;
                statusMessage = "Checking walkthrough visual mode";
              }
            ];
          }
        ];
      };
    };

  den.aspects.ai.hjem =
    { pkgs, ... }:
    {
      packages = with pkgs; [
        claude-code
        opencode

        # Repositories and GitHub.
        git
        gh
        # Search and inspection.
        ripgrep
        fd
        file
        tree
        # Structured data.
        jq
        yq-go
        sqlite
        # Fetching and archives.
        curl
        wget
        unzip
        zip
        # Throwaway scripts are usually Python, and MCP servers start through uvx or npx.
        python3
        uv
        nodejs
      ];

      # The /walkthrough skill, its scripts and hook, from the same input as the
      # Neovim plugin (modules/features/neovim.nix), so both stay in step.
      # clobber replaces the hand-made symlink this used to be.
      files.".claude/skills/walkthrough" = {
        source = "${inputs.walkthrough-nvim}/claude/skills/walkthrough";
        clobber = true;
      };

      # uv would otherwise download its own Python builds, which only run through nix-ld.
      environment.sessionVariables = {
        UV_PYTHON = "${pkgs.python3}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
      };
    };
}
