{
  den.aspects.yubikey = {
    nixos = { pkgs, ... }: {
      services.pcscd.enable = true;

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-qt;
      };

      # gpg-agent handles ssh requests instead
      programs.ssh.startAgent = false;

      services.udev.packages = [
        pkgs.yubikey-personalization
      ];

      environment.systemPackages = [
        pkgs.age-plugin-yubikey
        pkgs.yubikey-manager
      ];
    };

    provides.to-users.hjem.files.".gnupg/scdaemon.conf".text = ''
      disable-ccid
    '';
  };
}
