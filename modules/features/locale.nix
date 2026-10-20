{ den, ... }:

{
  den.aspects.locale.nixos = {
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocales = [ "de_DE.UTF-8/UTF-8" ];
      extraLocaleSettings = {
        LC_CTYPE = "en_US.UTF-8";
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MESSAGES = "en_US.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
        LC_COLLATE = "de_DE.UTF-8";
      };
    };

    time.timeZone = "Europe/Berlin";

    services.xserver.xkb = {
      layout = "us";
      variant = "intl";
    };

    # Since GTK 4.20, GTK delegates dead keys and compose sequences to the
    # Wayland text-input protocol. Without an input method (fcitx5/ibus),
    # dead keys such as ' " ` are swallowed in GTK4 apps like Ghostty.
    # Use GTK's built-in handling until an input method is configured.
    # Remove this if you enable i18n.inputMethod.
    environment.sessionVariables.GTK_IM_MODULE = "simple";
  };

  den.schema.host.includes = [ den.aspects.locale ];
}
