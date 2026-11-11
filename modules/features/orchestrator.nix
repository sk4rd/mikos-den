{ inputs, ... }:

{
  den.aspects.orchestrator.hjem =
    { pkgs, ... }:
    {
      packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.orchestrator ];
    };
}
