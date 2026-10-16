let
  sources = import ./npins;
  with-inputs = import sources.with-inputs sources { };
  outputs =
    inputs:
    (inputs.nixpkgs.lib.evalModules {
      modules = [ (inputs.import-tree ./modules) ];
      specialArgs.inputs = inputs;
    }).config.flake;
in
with-inputs outputs
