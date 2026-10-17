{ den, ... }:

{
  # Declare miko user on all hosts
  den.schema.host.users.miko = { };

  den.aspects.miko = {
    includes = [
      den.batteries.define-user
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
    ];

    user = {
      createHome = true;
      description = "Mikołaj Bajtkiewicz";
    };
  };
}
