{ den, ... }:

{
  # Declare miko user on all hosts
  den.schema.host.users.miko.classes = [ "hjem" ];

  den.aspects.miko = {
    includes = [
      den.batteries.host-aspects
      den.batteries.define-user
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
      den.aspects.ghostty
      den.aspects.neovim
      den.aspects.yubikey
    ];

    user = {
      createHome = true;
      description = "Mikołaj Bajtkiewicz";
    };
  };
}
