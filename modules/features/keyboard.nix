{ inputs, ... }:

{
  flake.packages.x86_64-linux.charybdis-hud-firmware =
    inputs.keyboard-hud.packages.x86_64-linux.charybdis-firmware;

  den.aspects.keyboard = {
    hjem.files.".config/umbriel/conf.d/keyboard-hud.toml".text = ''
      [keybinds]
      "Mod+B" = { action = "spawn keyboard-hud", repeat = false }
      "Mod+Shift+B" = { action = "spawn keyboard-hud --move", repeat = false }
    '';

    nixos = { host, ... }: {
      imports = [ inputs.keyboard-hud.nixosModules.default ];

      services.xserver.xkb = {
        layout = "eu";
        variant = "";
      };

      # Argos (WebHID) opens the Charybdis' hidraw nodes too.
      services.udev.extraRules = ''
        KERNEL=="hidraw*", ATTRS{idVendor}=="a8f8", MODE="0660", GROUP="users", TAG+="uaccess"
      '';

      # The layout lives outside this repo, in ~/.config/keyboard-hud/layout.json.
      programs.keyboard-hud = {
        enable = true;
        theme = {
          background = host.theme.colors.bg;
          foreground = host.theme.colors.fg;
          palette = host.theme.ansiNamed;
        };
        hidrawAccess = false;
        shortcut = null;
      };
    };
  };
}
