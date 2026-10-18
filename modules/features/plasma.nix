{
  den.aspects.plasma = {
    nixos = { pkgs, ... }: {
      services = {
        displayManager.sddm.enable = true;
        displayManager.sddm.wayland.enable = true;
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

    };

    hjem = { pkgs, ... }: {
    };
  };
}
