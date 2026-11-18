{
  description = "Miko's Den configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Brave was re-added on master on 2026-11-07. Drop this once it reaches nixpkgs-unstable.
    nixpkgs-brave.url = "github:NixOS/nixpkgs/master";
    den.url = "github:denful/den";
    den-diagram = {
      url = "github:denful/den-diagram";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fork with scratchpad-window-toggle, umbriel_output_rect for shaders, and fixes for scratchpad windows that
    # replay their show or hide animation.
    umbriel = {
      url = "github:sk4rd/umbriel?ref=fix/scratchpad-hiding-refade";
      flake = false;
    };

    # Fork of LBurny/cadpilot with the fixes found modelling in FreeCAD 1.1.
    cadpilot = {
      url = "github:sk4rd/cadpilot";
      flake = false;
    };

    keyboard-hud = {
      url = "github:sk4rd/keyboard-hud";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      modules = [ (inputs.import-tree ./modules) ];
      specialArgs.inputs = inputs;
    }).config.flake;
}
