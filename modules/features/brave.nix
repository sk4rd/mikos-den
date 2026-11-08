{ config, inputs, ... }:

{
  den.aspects.brave.nixos = { pkgs, ... }: {
    # nixpkgs-unstable's chromium module no longer writes /etc/brave policies.
    disabledModules = [ "programs/chromium.nix" ];
    imports = [ "${inputs.nixpkgs-brave}/nixos/modules/programs/chromium.nix" ];

    environment.systemPackages = [
      inputs.nixpkgs-brave.legacyPackages.${pkgs.stdenv.hostPlatform.system}.brave
    ];

    programs.chromium = {
      enable = true;
      extraOpts.BrowserThemeColor = config.theme.colors.bg;
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

      extraOptsRecommended = {
        PasswordManagerEnabled = false;

        DefaultSearchProviderEnabled = true;
        DefaultSearchProviderName = "Startpage";
        DefaultSearchProviderKeyword = "startpage.com";
        DefaultSearchProviderSearchURL = "https://www.startpage.com/sp/search?query={searchTerms}";
      };
    };

    xdg.mime.defaultApplications = {
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "text/html" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
    };
  };
}
