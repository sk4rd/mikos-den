{ den, ... }:

{
  den.aspects.ai.includes = [
    (den.batteries.unfree [ "claude-code" ])
    den.aspects.orchestrator
  ];

  # Agents install tools on the fly (uv wheels, npm packages with prebuilt
  # binaries), and those expect a normal Linux loader. nix-ld provides one.
  den.aspects.ai.nixos.programs.nix-ld.enable = true;

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

      # uv would otherwise download its own Python builds, which only run through nix-ld.
      environment.sessionVariables = {
        UV_PYTHON = "${pkgs.python3}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
      };
    };
}
