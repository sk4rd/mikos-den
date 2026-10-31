{ den, inputs, ... }:
let
  diagram = inputs.den-diagram.lib;
  graph = diagram.graph.flattenEntityKinds (
    diagram.graph.foldProviders (
      diagram.graph.ofNamespace {
        aspects = den.aspects;
        name = "mikos-den";
        direction = "LR";
      }
    )
  );
in
{
  flake.diagrams.overview = diagram.toMermaid graph;
}
