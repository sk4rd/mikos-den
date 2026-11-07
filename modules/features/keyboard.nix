{
  config,
  den,
  inputs,
  ...
}:

{
  # HUD firmware for the Charybdis. Flash both halves in bootloader mode (double-tap reset) by
  # copying the .uf2 onto the RPI-RP2 drive, then re-import your layout in Argos:
  # VIA resets its keymap the first time the build changes.
  flake.packages.x86_64-linux.charybdis-hud-firmware =
    inputs.keyboard-hud.packages.x86_64-linux.charybdis-firmware;

  den.aspects.keyboard = {
    nixos = {
      imports = [ inputs.keyboard-hud.nixosModules.default ];

      # EurKEY: US typing, with German letters on AltGr+A/O/U/S.
      services.xserver.xkb = {
        layout = "eu";
        variant = "";
      };

      # Lets Argos (WebHID) and keyboard-hud open the Charybdis' hidraw nodes.
      services.udev.extraRules = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="a8f8", MODE="0660", GROUP="users", TAG+="uaccess"
      '';

      # Live overlay of the Argos layout; toggle with Meta+Alt+K or from the tray.
      # The layout lives outside this repo, in ~/.config/keyboard-hud/layout.json.
      programs.keyboard-hud = {
        enable = true;
        theme = {
          background = config.theme.colors.bg;
          foreground = config.theme.colors.fg;
          palette = config.theme.ansiNamed;
        };
        hidrawAccess = false; # granted above
      };
    };
  };
}
