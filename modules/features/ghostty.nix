{ den, ... }:

{
  den.aspects.ghostty = {
    includes = [ den.aspects.theme ];

    provides.to-hosts.nixos = { pkgs, ... }: {
      fonts.packages = with pkgs; [ nerd-fonts.blex-mono ];

      environment.sessionVariables.TERMINAL = "${pkgs.ghostty}/bin/ghostty";
      environment.etc."xdg/kdeglobals".text = ''
        [General]
        TerminalApplication=${pkgs.ghostty}/bin/ghostty
        TerminalService=com.mitchellh.ghostty.desktop
      '';
    };

    hjem = { pkgs, config, ... }: {
      packages = with pkgs; [ ghostty ];

      files.".config/ghostty/config.ghostty".text = ''
        theme = ${config.miko.theme.name}
        font-family = BlexMono Nerd Font Mono
        font-size = 10
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
