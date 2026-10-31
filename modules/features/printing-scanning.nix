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

    provides.to-users.user.extraGroups = [
      "lp"
      "scanner"
    ];
  };
}
