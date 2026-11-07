{ den, ... }:

let
  kcminputrc = ''
    [Libinput][Defaults][Pointer]
    NaturalScroll=false
    PointerAccelerationProfile=1

    [Libinput][Defaults][Touchpad]
    NaturalScroll=true
    PointerAccelerationProfile=2
    ScrollFactor=0.5
  '';
in
{
  den.aspects.plasma = {
    nixos =
      { pkgs, ... }:
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        environment.etc."xdg/kdeglobals".text = ''
          [General]
          TerminalApplication=${pkgs.ghostty}/bin/ghostty
          TerminalService=com.mitchellh.ghostty.desktop
        '';

        xdg.mime.defaultApplications = {
          "application/pdf" = "okularApplication_pdf.desktop";

          "image/avif" = "org.kde.gwenview.desktop";
          "image/bmp" = "org.kde.gwenview.desktop";
          "image/gif" = "org.kde.gwenview.desktop";
          "image/jpeg" = "org.kde.gwenview.desktop";
          "image/png" = "org.kde.gwenview.desktop";
          "image/svg+xml" = "org.kde.gwenview.desktop";
          "image/tiff" = "org.kde.gwenview.desktop";
          "image/webp" = "org.kde.gwenview.desktop";

          "video/mp4" = "org.kde.haruna.desktop";
          "video/mpeg" = "org.kde.haruna.desktop";
          "video/quicktime" = "org.kde.haruna.desktop";
          "video/webm" = "org.kde.haruna.desktop";
          "video/x-matroska" = "org.kde.haruna.desktop";
          "video/x-msvideo" = "org.kde.haruna.desktop";
        };

        services = {
          displayManager.sddm.enable = true;
          displayManager.sddm.wayland.enable = true;
          desktopManager.plasma6.enable = true;

          orca.enable = false;
          geoclue2.enable = false;
        };

        # SDDM's PAM stack includes the login service
        security.pam.services.login.fprintAuth = false;

        programs.kde-pim.enable = false;

        environment.plasma6.excludePackages = with pkgs.kdePackages; [
          aurorae
          discover
          elisa
          gwenview
          kate
          khelpcenter
          konsole
          krdp
          ktexteditor
          okular
          plasma-browser-integration
          plasma-keyboard
          plasma-workspace-wallpapers
          qtvirtualkeyboard
          union
        ];

        systemd.tmpfiles.rules = [
          "d /var/lib/sddm/.config 0755 sddm sddm -"
          "L+ /var/lib/sddm/.config/kcminputrc - - - - ${pkgs.writeText "sddm-kcminputrc" kcminputrc}"
        ];
      };

    hjem =
      { pkgs, ... }:
      {
        packages = [
          pkgs.kdePackages.gwenview
          pkgs.haruna
          pkgs.kdePackages.okular
        ];

        files.".config/kcminputrc" = {
          text = kcminputrc;
          clobber = true;
        };

        files.".config/ksmserverrc" = {
          text = ''
            [General]
            loginMode=emptySession
          '';
          clobber = true;
        };

        # Vim-style window motions.
        systemd.services.plasma-vim-shortcuts = {
          description = "Configure Plasma Vim window shortcuts";
          wantedBy = [
            "plasma-kwin_wayland.service"
            "plasma-kwin_x11.service"
            "plasma-kglobalaccel.service"
          ];
          before = [
            "plasma-kwin_wayland.service"
            "plasma-kwin_x11.service"
            "plasma-kglobalaccel.service"
          ];
          serviceConfig.Type = "oneshot";
          script = ''
            set_shortcut() {
              ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kglobalshortcutsrc --group "$1" --key "$2" "$3"
            }

            set_shortcut ksmserver 'Lock Session' $'Screensaver\tMeta+Ctrl+L,Screensaver\tMeta+L,Lock Session'
            set_shortcut kwin 'Switch Window Left' 'Meta+H,Meta+Alt+Left,Switch to Window to the Left'
            set_shortcut kwin 'Switch Window Down' 'Meta+J,Meta+Alt+Down,Switch to Window Below'
            set_shortcut kwin 'Switch Window Up' 'Meta+K,Meta+Alt+Up,Switch to Window Above'
            set_shortcut kwin 'Switch Window Right' 'Meta+L,Meta+Alt+Right,Switch to Window to the Right'
            set_shortcut kwin 'Window Quick Tile Left' 'Meta+Shift+H,Meta+Left,Quick Tile Window to the Left'
            set_shortcut kwin 'Window Quick Tile Bottom' 'Meta+Shift+J,Meta+Down,Quick Tile Window to the Bottom'
            set_shortcut kwin 'Window Quick Tile Top' 'Meta+Shift+K,Meta+Up,Quick Tile Window to the Top'
            set_shortcut kwin 'Window Quick Tile Right' 'Meta+Shift+L,Meta+Right,Quick Tile Window to the Right'
            # Meta+T opens Ghostty, see ghostty.nix.
            set_shortcut kwin 'Edit Tiles' 'none,Meta+T,Toggle Tiles Editor'
          '';
        };

      };
  };
}
