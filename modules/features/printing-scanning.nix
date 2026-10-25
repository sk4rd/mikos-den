{
  den.aspects.printing-scanning = {
    nixos = {
      services = {
        printing.enable = true;
        ipp-usb.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
      };

      hardware.sane.enable = true;
    };

    provides.to-users = { user, ... }: {
      nixos = { config, lib, ... }: {
        users.users.${user.userName}.extraGroups =
          lib.mkIf config.users.users.${user.userName}.isNormalUser
            [
              "lp"
              "scanner"
            ];
      };
    };
  };
}
