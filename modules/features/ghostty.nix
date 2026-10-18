{
  den.aspects.ghostty.nixos = { pkgs, ... }: {
    fonts.packages = with pkgs; [ nerd-fonts.blex-mono ];
  };

  den.aspects.ghostty.hjem = { pkgs, ... }: {
    packages = with pkgs; [ ghostty ];

    files.".config/ghostty/config.ghostty".text = ''
      theme = Firefox Dev
      font-family = BlexMono Nerd Font Mono
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
}
