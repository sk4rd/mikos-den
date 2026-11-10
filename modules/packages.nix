{ inputs, ... }:
let
  system = "x86_64-linux";
in
{
  imports = [ inputs.den.flakeOutputs.packages ];

  flake.packages.${system} = inputs.nixpkgs.lib.packagesFromDirectoryRecursive {
    inherit (inputs.nixpkgs.legacyPackages.${system}) callPackage;
    directory = ../pkgs;
  };
}
