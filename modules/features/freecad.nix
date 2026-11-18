{ inputs, ... }:

let
  cadpilot =
    pkgs:
    pkgs.python3Packages.buildPythonApplication {
      pname = "cadpilot";
      version = "0.7.7-${inputs.cadpilot.shortRev}";
      pyproject = true;
      src = inputs.cadpilot;

      build-system = [ pkgs.python3Packages.hatchling ];
      dependencies =
        with pkgs.python3Packages;
        [
          mcp
          validators
        ]
        ++ mcp.optional-dependencies.cli;

      nativeCheckInputs = [ pkgs.python3Packages.pytestCheckHook ];

      # The server talks to this add-on over RPC, so the two are pinned together. It goes into FreeCAD's Mod folder.
      postInstall = ''
        mkdir -p $out/share/cadpilot
        cp -r addon/CADPilot $out/share/cadpilot/
      '';

      meta.mainProgram = "cadpilot";
    };
  # Every CADPilot tool but the two that run arbitrary Python, which keep asking first.
  tools = [
    "create_document"
    "open_document"
    "save_document"
    "cad"
    "get_task_result"
    "get_view"
    "get_objects"
    "list_documents"
    "session"
    "step_plan"
    "step_control"
    "get_addon_log"
    "diagnose"
    "save_pattern"
    "recall_patterns"
    "operation_help"
    "inspect_freecad"
    "measure_geometry"
    "get_topology"
    "check_interference"
    "get_positioning_info"
    "align_shapes"
    "get_anchors"
    "set_anchors"
    "assemble"
    "verify_assembly"
    "assembly_session"
  ];
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
                name = "cadpilot";
                source = "./cadpilot";
                description = "Model in the running FreeCAD with Claude through CADPilot";
              }
            ];
          };
          "cadpilot/.claude-plugin/plugin.json" = {
            name = "cadpilot";
            # Claude Code keeps installed plugins in a cache keyed by version, so a change here needs a new one.
            inherit (cadpilot pkgs) version;
            description = "Model in the running FreeCAD with Claude through CADPilot";
          };
          "cadpilot/.mcp.json".mcpServers.cadpilot = {
            type = "stdio";
            command = pkgs.lib.getExe (cadpilot pkgs);
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
          enabledPlugins."cadpilot@mikos-den" = true;
          permissions.allow = map (tool: "mcp__plugin_cadpilot_cadpilot__${tool}") tools;
        };
      };

    provides.to-users.hjem =
      { pkgs, ... }:
      {
        packages = [ pkgs.freecad ];
        files.".local/share/FreeCAD/v1-1/Mod/CADPilot" = {
          source = "${cadpilot pkgs}/share/cadpilot/CADPilot";
          # A link made by hand may already sit there.
          clobber = true;
        };
      };
  };
}
