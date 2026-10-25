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

    # yubikey age identity (PIV slot 2), pass it with -i
    provides.to-users.hjem.files.".config/age/keys.txt" = {
      text = ''
        AGE-PLUGIN-YUBIKEY-1SX7C5QVRPRM8U3CW29PK5
      '';
      type = "copy";
      permissions = "600";
    };

    # autoloaded only when agenix runs, and works for pasted or recalled lines
    provides.to-users.hjem.files.".config/fish/functions/agenix.fish".text = ''
      function agenix --wraps=agenix --description 'agenix with the YubiKey age identity'
          if contains -- -i $argv; or contains -- --identity $argv
              command agenix $argv
          else
              command agenix -i ~/.config/age/keys.txt $argv
          end
      end
    '';

    provides.to-users.hjem.files.".gnupg/scdaemon.conf".text = ''
      disable-ccid
    '';
  };
}
