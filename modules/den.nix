{
  inputs,
  den,
  lib,
  ...
}:

{
  imports = [ inputs.den.flakeModule ];
  den.default.includes = [ den.batteries.hostname ];
  den.default.nixos.system.stateVersion = "26.11";

  # Structural, so den doesn't read an aspect's typed settings as a child aspect.
  den.reservedKeys = [ "settings" ];

  den.quirks.service-routes.description = "Reverse-proxy routes contributed by services";
  den.quirks.status-endpoints.description = "Health endpoints contributed by services";
  den.quirks.status-heartbeats.description = "Results pushed to Gatus by services";
  den.quirks.storage-datasets.description = "Dataset definitions contributed by services";

  den.schema.host.imports = [
    {
      options.settings = lib.mkOption {
        type = import ../lib/settings-type.nix { inherit den lib; };
        default = { };
        description = "Per-aspect typed settings";
      };
    }
  ];
}
