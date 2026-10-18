{
  den.aspects.brave.nixos = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.brave ];

    # This module writes settings for chromium based browsers such as brave
    programs.chromium = {
      enable = true;
      extraOpts.ExtensionSettings = {
        # Dark Reader
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
          toolbar_pin = "force_pinned";
        };
        # Proton Pass
        "ghmbeldphafepmbegfdlkpapadhbakde" = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
          toolbar_pin = "force_pinned";
        };
      };

      extraOptsRecommended.PasswordManagerEnabled = false;
    };

    xdg.mime.defaultApplications = {
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "text/html" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
    };
  };
}
