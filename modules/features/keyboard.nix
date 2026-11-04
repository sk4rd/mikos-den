{
  config,
  den,
  inputs,
  ...
}:

{
  # HUD firmware for the Charybdis. Flash both halves in bootloader mode (double-tap reset) by
  # copying the .uf2 onto the RPI-RP2 drive, then re-import keyboard-argos-layout.json in Argos:
  # VIA resets its keymap the first time the build changes.
  flake.packages.x86_64-linux.charybdis-hud-firmware =
    inputs.keyboard-hud.packages.x86_64-linux.charybdis-firmware;

  den.aspects.keyboard = {
    nixos = {
      imports = [ inputs.keyboard-hud.nixosModules.default ];

      services.xserver.xkb = {
        layout = "us";
        variant = "altgr-intl";
      };

      # Lets Argos (WebHID) and keyboard-hud open the Charybdis' hidraw nodes.
      services.udev.extraRules = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="a8f8", MODE="0660", GROUP="users", TAG+="uaccess"
      '';

      # Live overlay of the Argos layout; toggle with Meta+Alt+K or from the tray.
      # Replace keyboard-argos-layout.json with a fresh Argos export when the layout changes.
      programs.keyboard-hud = {
        enable = true;
        layout = ./keyboard-argos-layout.json;
        theme = {
          background = config.theme.colors.bg;
          foreground = config.theme.colors.fg;
          palette = config.theme.ansiNamed;
        };
        hidrawAccess = false; # granted above
      };

      # GTK 4.20 swallows dead keys without an input method; drop this once i18n.inputMethod is set.
      environment.sessionVariables.GTK_IM_MODULE = "simple";
    };
  };
}
