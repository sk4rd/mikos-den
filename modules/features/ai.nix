{ den, inputs, ... }:

{
  den.aspects.ai.includes = [
    (den.batteries.unfree [ "claude-code" ])
    den.aspects.orchestrator
  ];

  den.aspects.ai.hjem =
    { pkgs, ... }:
    {
      packages = [
        pkgs.claude-code
        inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.reasonix
      ];
    };
}
