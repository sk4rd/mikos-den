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

        users.users = lib.mapAttrs (_: _: {
          initialPassword = lib.mkForce "test";
          password = lib.mkForce null;
          hashedPassword = lib.mkForce null;
          hashedPasswordFile = lib.mkForce null;
          initialHashedPassword = lib.mkForce null;
        }) (lib.filterAttrs (_: user: user.isNormalUser) config.users.users);

        age.secrets.miko-password.enable = lib.mkIf (config.age.secrets ? miko-password) (
          lib.mkForce false
        );
      };
    };

  den.schema.host.includes = [ den.aspects.nixos-testing-vm ];
}
