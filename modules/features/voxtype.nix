{ ... }:

{
  den.aspects.voxtype = {
    # Types through a virtual keyboard: Plasma has no wtype protocol, and uinput
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
          # Plasma owns the shortcut, because reading keys here needs the input group.
          hotkey.enabled = false;
          whisper = {
            model = "${model}";
            language = "en";
            # A hint rather than a guarantee: it steers Whisper towards these spellings.
            initial_prompt = "Nix, NixOS, nixpkgs, flake, Plasma, Jellyfin, agenix, Vulkan.";
          };
          # The nixpkgs build ships no working OSD, so these are the only recording signals.
          audio = {
            feedback.enabled = true;
            max_duration_secs = 600;
          };
          output = {
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

        # No modifiers: Plasma reads typed text as shortcuts while one is still held.
        files.".local/share/kglobalaccel/voxtype-toggle.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Toggle Dictation
          Exec=${voxtype}/bin/voxtype record toggle
          Terminal=false
          StartupNotify=false
          X-KDE-Shortcuts=F9
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
          serviceConfig = {
            ExecStart = "${voxtype}/bin/voxtype -q daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
  };
}
