{ inputs, ... }:

let
  freecad-mcp = pkgs: inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.freecad-mcp;
in
{
  den.aspects.freecad = {
    # Claude Code rewrites ~/.claude.json and managed-mcp.json would lock out every other server, so the MCP server
    # reaches it as a plugin from a store marketplace, which managed settings install and enable.
    nixos =
      { pkgs, ... }:
      let
        files = {
          ".claude-plugin/marketplace.json" = {
            name = "mikos-den";
            owner.name = "mikos-den";
            description = "Plugins installed by mikos-den";
            plugins = [
              {
                name = "freecad";
                source = "./freecad";
                description = "Create and edit models in the running FreeCAD through freecad-mcp";
              }
            ];
          };
          "freecad/.claude-plugin/plugin.json" = {
            name = "freecad";
            # Claude Code keeps installed plugins in a cache keyed by version, so an update needs a new one.
            inherit (freecad-mcp pkgs) version;
            description = "Create and edit models in the running FreeCAD through freecad-mcp";
          };
          "freecad/.mcp.json".mcpServers.freecad = {
            type = "stdio";
            command = pkgs.lib.getExe (freecad-mcp pkgs);
            args = [ ];
          };
        };
        # Real files, not store symlinks: Claude Code reads MCP server files without following symlinks.
        marketplace = pkgs.runCommand "claude-marketplace-mikos-den" { } (
          pkgs.lib.concatStrings (
            pkgs.lib.mapAttrsToList (path: value: ''
              install -Dm444 ${pkgs.writeText (baseNameOf path) (builtins.toJSON value)} "$out/${path}"
            '') files
          )
        );
      in
      {
        environment.etc."claude-code/managed-settings.d/freecad.json".text = builtins.toJSON {
          extraKnownMarketplaces.mikos-den.source = {
            source = "directory";
            path = "${marketplace}";
          };
          enabledPlugins."freecad@mikos-den" = true;
        };
      };

    provides.to-users.hjem =
      { pkgs, ... }:
      {
        packages = [ pkgs.freecad ];
        # The workbench whose RPC server freecad-mcp drives.
        files.".local/share/FreeCAD/v1-1/Mod/FreeCADMCP".source =
          "${freecad-mcp pkgs}/share/freecad-mcp/FreeCADMCP";
      };
  };
}
