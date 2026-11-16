{
  inputs,
  den,
  lib,
  ...
}:

{
  imports = [ inputs.den.flakeModule ];
  den = {
    default.includes = [ den.batteries.hostname ];
    default.nixos.system.stateVersion = "26.11";

    reservedKeys = [ "settings" ];

    quirks = {
      service-routes.description = "Reverse-proxy routes contributed by services";
      status-endpoints.description = "Health endpoints contributed by services";
      status-heartbeats.description = "Results pushed to Gatus by services";
      storage-datasets.description = "Dataset definitions contributed by services";
    };

    schema.host.imports = [
      {
        options.settings = lib.mkOption {
          type = import ../lib/settings-type.nix { inherit den lib; };
          default = { };
          description = "Per-aspect typed settings";
        };
      }
    ];
  };
}
