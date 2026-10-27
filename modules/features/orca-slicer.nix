{ ... }:

{
  den.aspects.orca-slicer.hjem = { pkgs, ... }: {
    packages = [ pkgs.orca-slicer ];

    files.".config/environment.d/orca-slicer.conf".text = ''
      SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    '';

    systemd.services.orca-slicer-config = {
      description = "Configure OrcaSlicer cloud HTTPS endpoint";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "orca-slicer-config" ''
          set -eu
          if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -x orcaslicer_main >/dev/null; then
            echo "Close OrcaSlicer before starting orca-slicer-config" >&2
            exit 1
          fi
          umask 077
          dir="''${XDG_CONFIG_HOME:-$HOME/.config}/OrcaSlicer"
          ${pkgs.coreutils}/bin/mkdir -p "$dir"
          tmp="$(${pkgs.coreutils}/bin/mktemp "$dir/.config.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
          if [ -e "$dir/OrcaSlicer.conf" ]; then
            ${pkgs.jq}/bin/jq '.app.orca_api_url = "https://api.orcaslicer.com"' "$dir/OrcaSlicer.conf" > "$tmp"
          else
            ${pkgs.jq}/bin/jq -n '{app: {orca_api_url: "https://api.orcaslicer.com"}}' > "$tmp"
          fi
          ${pkgs.coreutils}/bin/mv "$tmp" "$dir/OrcaSlicer.conf"
        '';
      };
    };
  };
}
