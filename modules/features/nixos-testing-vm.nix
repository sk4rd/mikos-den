{ den, ... }:

{
  den.aspects.nixos-testing-vm.nixos =
    { config, lib, ... }:
    {
      virtualisation.vmVariant = {
        virtualisation = {
          memorySize = 4096;
          cores = 4;
        };

        # Keep existing normal users and their configuration.
        # Override only their VM login credentials.
        users.users = lib.mapAttrs (_: _: {
          initialPassword = lib.mkForce "test";
          password = lib.mkForce null;
          hashedPassword = lib.mkForce null;
          hashedPasswordFile = lib.mkForce null;
          initialHashedPassword = lib.mkForce null;
        }) (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);
      };
    };

  den.schema.host.includes = [ den.aspects.nixos-testing-vm ];
}
