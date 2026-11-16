_:

{
  den.aspects.voxtype = {
    # Types through a virtual keyboard: uinput works under any compositor and
    # avoids the input group, which could read every keystroke.
    provides.to-hosts.nixos.hardware.uinput.enable = true;
    user.extraGroups = [ "uinput" ];

    hjem =
      { pkgs, ... }:
      let
        voxtype = pkgs.voxtype-vulkan;

        model = pkgs.fetchurl {
          url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
          hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
        };

        config = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
          # Umbriel owns the shortcut, because reading keys here needs the input group.
          hotkey.enabled = false;
          whisper = {
            model = "${model}";
            language = "en";
            # A hint rather than a guarantee: it steers Whisper towards these spellings.
            initial_prompt = "Nix, NixOS, nixpkgs, flake, Noctalia, Umbriel, Jellyfin,
            agenix, Vulkan, mikos-den.";
          };
          osd.frontend = "quickshell";
          audio = {
            feedback.enabled = true;
            max_duration_secs = 600;
          };
          output = {
            # Give Mod time to be released before virtual keystrokes can trigger shortcuts.
            pre_type_delay_ms = 500;
            notification.on_recording_start = true;
            mode = "type";
            driver_order = [
              "dotool"
              "clipboard"
            ];
          };
        };
      in
      {
        packages = [ voxtype ];

        files.".config/voxtype/config.toml".source = config;

        files.".config/umbriel/conf.d/voxtype.toml".text = ''
          [keybinds]
          "Mod+D" = { action = "spawn ${voxtype}/bin/voxtype record toggle", repeat = false }
        '';

        systemd.services.voxtype = {
          description = "Voxtype voice-to-text daemon";
          partOf = [ "graphical-session.target" ];
          after = [
            "graphical-session.target"
            "pipewire.service"
            "pipewire-pulse.service"
          ];
          wantedBy = [ "graphical-session.target" ];
          # The daemon launches the overlay as a child, and nixpkgs leaves out its QML
          # files and runtime tools.
          environment.VOXTYPE_OSD_QML_PATH = "${voxtype.src}/quickshell";
          path = [
            pkgs.dotool
            pkgs.quickshell
            voxtype
          ];
          serviceConfig = {
            ExecStart = "${voxtype}/bin/voxtype -q daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
  };
}
