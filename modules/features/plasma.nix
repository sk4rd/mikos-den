{ den, ... }:

let
  kcminputrc = ''
    [Libinput][Defaults][Pointer]
    NaturalScroll=true
    PointerAccelerationProfile=1

    [Libinput][Defaults][Touchpad]
    NaturalScroll=true
    PointerAccelerationProfile=2
  '';
in
{
  den.aspects.plasma = {
    includes = [ den.aspects.printing-scanning ];

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

      # Pointer settings for the login screen
      systemd.tmpfiles.rules = [
        "d /var/lib/sddm/.config 0755 sddm sddm -"
        "L+ /var/lib/sddm/.config/kcminputrc - - - - ${pkgs.writeText "sddm-kcminputrc" kcminputrc}"
      ];
    };

    hjem = { pkgs, ... }: {
      # Apply pointer accel profile to plasma
      files.".config/kcminputrc" = {
        text = kcminputrc;
        clobber = true;
      };

    };
  };
}
