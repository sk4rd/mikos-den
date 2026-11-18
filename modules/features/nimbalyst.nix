{ inputs, ... }:

{
  den.aspects.nimbalyst.hjem =
    { pkgs, ... }:
    {
      packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nimbalyst ];
    };
}
