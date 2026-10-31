{ den, ... }:

{
  den.aspects.ghostty = {
    includes = [ den.aspects.theme ];

    provides.to-hosts.nixos = { pkgs, ... }: {
      environment.sessionVariables.TERMINAL = "${pkgs.ghostty}/bin/ghostty";
    };

    hjem = { pkgs, ... }: {
      packages = with pkgs; [ ghostty ];

      files.".config/ghostty/config.ghostty".text = ''
        theme = ${den.aspects.theme.miko.theme.name}
        font-family = BlexMono Nerd Font Mono
        font-size = 10
        shell-integration = fish
      '';

      # Register default plasma shortcut
      files.".local/share/kglobalaccel/com.mitchellh.ghostty-shortcut.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Ghostty
        Exec=${pkgs.ghostty}/bin/ghostty
        Icon=com.mitchellh.ghostty
        Terminal=false
        StartupNotify=false
        X-KDE-Shortcuts=Ctrl+Alt+T
      '';
    };
  };
}
