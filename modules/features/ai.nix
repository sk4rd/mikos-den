{ den, ... }:

{
  den.aspects.ai = {
    includes = [
      (den.batteries.unfree [ "claude-code" ])
    ];

    # Agents install tools on the fly (uv wheels, npm packages with prebuilt
    # binaries), and those expect a normal Linux loader. nix-ld provides one.
    nixos.programs.nix-ld.enable = true;

    # Claude Code settings for every host that has this aspect. Claude Code reads
    # /etc/claude-code/managed-settings.json in addition to
    # ~/.claude/settings.json, which it and other tools rewrite and which can
    # therefore not come from the store.
    # See https://code.claude.com/docs/en/settings (managed settings).
    nixos.environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
      # Saves the subscription limits for the Noctalia usage widget, then runs the status
      # line from ~/.claude/settings.json. A managed statusLine replaces the user's one,
      # and the status line command is the only place Claude Code reports the limits.
      # See https://code.claude.com/docs/en/statusline.
      statusLine = {
        type = "command";
        command = "bash ${./claude-statusline.sh}";
      };
    };

    hjem =
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

        # uv would otherwise download its own Python builds, which only run through nix-ld.
        environment.sessionVariables = {
          UV_PYTHON = "${pkgs.python3}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
        };
      };
  };
}
