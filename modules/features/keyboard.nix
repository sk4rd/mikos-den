{ den, ... }:

{
  den.aspects.keyboard.nixos = {
    services.xserver.xkb = {
      layout = "us";
      variant = "altgr-intl";
    };

    services.udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="a8f8", MODE="0660", GROUP="users", TAG+="uaccess"
    '';

    # GTK 4.20 swallows dead keys without an input method; drop this once i18n.inputMethod is set.
    environment.sessionVariables.GTK_IM_MODULE = "simple";
  };
}
