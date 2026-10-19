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

        # vm logs in with the test password above so the real password is not
        # needed
        age.secrets.miko-password.enable = lib.mkForce false;
      };
    };

  den.schema.host.includes = [ den.aspects.nixos-testing-vm ];
}
