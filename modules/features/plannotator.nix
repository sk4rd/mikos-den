{ inputs, ... }:

let
  plannotator = pkgs: inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.plannotator;
in
{
  den.aspects.plannotator = {
    nixos =
      { pkgs, ... }:
      {
        # The repository is its own marketplace. Taking it from the store keeps the plugin's hooks at the version of
        # the binary they call.
        environment.etc."claude-code/managed-settings.d/plannotator.json".text = builtins.toJSON {
          extraKnownMarketplaces.plannotator.source = {
            source = "directory";
            path = "${(plannotator pkgs).plugin}";
          };
          enabledPlugins."plannotator@plannotator" = true;
        };
      };

    hjem =
      { pkgs, ... }:
      {
        packages = [ (plannotator pkgs) ];
      };
  };
}
