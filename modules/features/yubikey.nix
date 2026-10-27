{
  den.aspects.yubikey =
    let
      identityFile = text: {
        inherit text;
        type = "copy";
        permissions = "600";
      };
    in
    {
      provides.to-hosts.nixos = { pkgs, ... }: {
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

      # age identities (PIV slot 2, name AGENIX), one file per YubiKey: given
      # several identities, age-plugin-yubikey also connects to the YubiKeys it
      # did not decrypt with and asks you to insert them
      provides.to-users.hjem.files.".config/age/keys-25869697.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1SX7C5QVRPRM8U3CW29PK5
      '';
      provides.to-users.hjem.files.".config/age/keys-23819186.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1KFEKKQVR979TCMQJL45JT
      '';

      # both identities, for plain `age -i ~/.config/age/keys.txt`
      provides.to-users.hjem.files.".config/age/keys.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1SX7C5QVRPRM8U3CW29PK5
        AGE-PLUGIN-YUBIKEY-1KFEKKQVR979TCMQJL45JT
      '';

      # autoloaded only when agenix runs, and works for pasted or recalled lines
      provides.to-users.hjem.files.".config/fish/functions/agenix.fish".text = ''
        function agenix --wraps=agenix --description 'agenix with the age identity of the connected YubiKey'
            if contains -- -i $argv; or contains -- --identity $argv
                command agenix $argv
                return
            end

            set -l serial (command ykman list --serials 2>/dev/null | head -n1)
            set -l identity ~/.config/age/keys-$serial.txt
            if not test -f $identity
                # unknown key or no PC/SC access: pass both identities instead
                set identity ~/.config/age/keys.txt
            end
            if not test -f $identity
                echo "agenix: no age identity for YubiKey '$serial'; pass -i explicitly" >&2
                return 1
            end

            command agenix -i $identity $argv
        end
      '';

      provides.to-users.hjem.files.".gnupg/scdaemon.conf".text = ''
        disable-ccid
        # share the PC/SC reader, so age-plugin-yubikey can talk to the
        # card while gpg-agent has it open (otherwise pcscd returns
        # "SCardConnect() Error Reader Exclusive")
        pcsc-shared
      '';
    };
}
