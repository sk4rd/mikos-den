{ config, ... }:

let
  inherit (config) theme;
in
{
  den.aspects.plasma = {
    nixos =
      { pkgs, ... }:
      {
        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        environment.etc."xdg/kcminputrc".source = ../../dots/plasma/kcminputrc;

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
          desktopManager.plasma6.enable = true;

          orca.enable = false;
          geoclue2.enable = false;
        };

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

        # Drop the old per-greeter override; the system-wide default applies.
        systemd.tmpfiles.rules = [
          "r /var/lib/sddm/.config/kcminputrc"
        ];
      };

    hjem =
      { pkgs, lib, ... }:
      let
        wallpaper = import ../../lib/theme/render/wallpaper.nix { inherit pkgs lib theme; };

        # Plasma rewrites these files, so apply the look at login.
        applyLook = pkgs.writeShellApplication {
          name = "apply-plasma-look";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.kdePackages.kconfig
            pkgs.kdePackages.plasma-workspace
          ];
          text = builtins.readFile ./plasma-apply-look.sh + ''

            kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
              --group org.kde.image --group General --key Image "file://${wallpaper}"

            # plasmashell may still be starting.
            for _ in $(seq 20); do
              plasma-apply-wallpaperimage ${wallpaper} && break
              sleep 1
            done
          '';
        };
      in
      {
        packages = [
          pkgs.kdePackages.gwenview
          pkgs.haruna
          pkgs.kdePackages.okular
        ];

        files.".config/kcminputrc" = {
          source = ../../dots/plasma/kcminputrc;
          clobber = true;
        };

        files.".config/autostart/plasma-look.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Apply Plasma look
          Exec=${applyLook}/bin/apply-plasma-look
          OnlyShowIn=KDE;
        '';

        files.".config/ksmserverrc" = {
          source = ../../dots/plasma/ksmserverrc;
          clobber = true;
        };

        # Vim-style window motions.
        systemd.services.plasma-vim-shortcuts = {
          description = "Configure Plasma Vim window shortcuts";
          wantedBy = [ "plasma-kwin_wayland.service" ];
          before = [ "plasma-kwin_wayland.service" ];
          path = [ pkgs.kdePackages.kconfig ];
          serviceConfig.Type = "oneshot";
          script = builtins.readFile ./plasma-vim-shortcuts.sh;
        };
      };
  };
}
