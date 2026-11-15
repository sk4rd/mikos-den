_:

{
  den.aspects.dolphin = {
    nixos =
      { pkgs, ... }:
      {
        # Removable drives show up in the Places panel through Solid, which asks udisks.
        services.udisks2.enable = true;

        # Apps that "show in folder" (Brave's downloads, for one) call the
        # org.freedesktop.FileManager1 D-Bus service, which Dolphin provides.
        services.dbus.packages = [ pkgs.kdePackages.dolphin ];

        # KService builds its list of apps from this menu. Outside Plasma there is no
        # applications.menu, so "Open With" stays empty. This one lists every app.
        environment.etc."xdg/menus/applications.menu".text = ''
          <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
            "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
          <Menu>
            <Name>Applications</Name>
            <DefaultAppDirs/>
            <DefaultDirectoryDirs/>
            <Include><All/></Include>
          </Menu>
        '';

        xdg.mime.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";
      };

    hjem =
      { pkgs, ... }:
      {
        packages = with pkgs.kdePackages; [
          dolphin
          # Thumbnails for images and PDFs, plus sftp://, smb:// and the trash.
          kio-extras
          kdegraphics-thumbnailers
          ffmpegthumbs
          # Lets non-KDE apps open files from sftp:// and smb:// locations.
          kio-fuse
          # Opens archives on double-click and adds Extract and Compress to the context
          # menu. It creates 7z archives with the `7z` from common-utils.
          ark
        ];

        files.".config/umbriel/conf.d/dolphin.toml".text = ''
          [keybinds]
          "Mod+E" = { action = "spawn dolphin", repeat = false }
        '';
      };
  };
}
