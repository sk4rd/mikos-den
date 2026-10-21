{ den, ... }:

{
  den.aspects.common-utils.hjem = { pkgs, ... }: {
    packages = with pkgs; [
      bat
      btop
      dust
      file
      fzf
      git
      jq
      killall
      lm_sensors
      lsof
      p7zip
      pciutils
      ripgrep
      tree
      usbutils
      wget
    ];
  };

  den.schema.user.includes = [ den.aspects.common-utils ];
}
