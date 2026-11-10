{ inputs, ... }:

{
  den.aspects.learnharness.hjem =
    { pkgs, ... }:
    {
      packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.learnharness ];
    };
}
