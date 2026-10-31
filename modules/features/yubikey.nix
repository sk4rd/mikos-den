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
          settings = {
            default-cache-ttl = 28800;
            max-cache-ttl = 86400;
            default-cache-ttl-ssh = 28800;
            max-cache-ttl-ssh = 86400;
            pinentry-timeout = 180;
          };
        };

        # gpg-agent handles ssh requests instead
        programs.ssh.startAgent = false;

        services.udev.packages = [
          pkgs.yubikey-personalization
        ];

        environment.systemPackages = [
          pkgs.age-plugin-yubikey
          pkgs.yubikey-manager
          # puts org.gnupg.pinentry-qt.desktop in XDG_DATA_DIRS so the
          # portal can focus the PIN dialog
          pkgs.pinentry-qt
        ];
      };

      # age identities (PIV slot 2, name AGENIX), one file per YubiKey: given
      # several identities, age-plugin-yubikey also connects to the YubiKeys it
      # did not decrypt with and asks you to insert them
      hjem.files.".config/age/keys-25869697.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1SX7C5QVRPRM8U3CW29PK5
      '';
      hjem.files.".config/age/keys-23819186.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1KFEKKQVR979TCMQJL45JT
      '';

      # both identities, for plain `age -i ~/.config/age/keys.txt`
      hjem.files.".config/age/keys.txt" = identityFile ''
        AGE-PLUGIN-YUBIKEY-1SX7C5QVRPRM8U3CW29PK5
        AGE-PLUGIN-YUBIKEY-1KFEKKQVR979TCMQJL45JT
      '';

      # autoloaded only when agenix runs, and works for pasted or recalled lines
      hjem.files.".config/fish/functions/agenix.fish".text = ''
        function agenix --wraps=agenix --description 'agenix with the age identity of the connected YubiKey'
            if contains -- -i $argv; or contains -- --identity $argv
                command agenix $argv
                return
            end

            # gpg-agent holds the reader exclusively; release it to pcscd
            command gpgconf --kill scdaemon 2>/dev/null

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

      # pcsc-shared disables scdaemon's PIN cache.
      # The agenix wrapper releases the card instead.
      hjem.files.".gnupg/scdaemon.conf".text = ''
        disable-ccid
      '';
    };
}
