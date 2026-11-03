{ config, den, lib, ... }:

let
  inherit (config) theme;
  c = theme.colors;

  btopTheme = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: ''theme[${k}]="${v}"'') {
      main_bg = c.bg;
      main_fg = c.fg;
      title = c.fg;
      hi_fg = c.blue;
      selected_bg = c.overlay;
      selected_fg = c.fgBright;
      inactive_fg = c.muted;
      graph_text = c.subtle;
      meter_bg = c.overlay;
      proc_misc = c.teal;
      cpu_box = c.blue;
      mem_box = c.green;
      net_box = c.purple;
      proc_box = c.pink;
      div_line = c.overlay;
      temp_start = c.green;
      temp_mid = c.yellow;
      temp_end = c.error;
      cpu_start = c.teal;
      cpu_mid = c.blue;
      cpu_end = c.purple;
      free_start = c.green;
      free_mid = c.teal;
      free_end = c.cyan;
      cached_start = c.blue;
      cached_mid = c.sky;
      cached_end = c.lightBlue;
      available_start = c.teal;
      available_mid = c.cyan;
      available_end = c.lightBlue;
      used_start = c.purple;
      used_mid = c.pink;
      used_end = c.error;
      download_start = c.blue;
      download_mid = c.sky;
      download_end = c.lightBlue;
      upload_start = c.purple;
      upload_mid = c.pink;
      upload_end = c.magenta;
      process_start = c.teal;
      process_mid = c.blue;
      process_end = c.purple;
    }
  );
in
{
  den.aspects.common-utils.hjem = { pkgs, ... }: {
    packages = with pkgs; [
      bat
      btop
      dust
      file
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

    # The ANSI theme follows the terminal palette.
    files.".config/bat/config".text = ''
      --theme=ansi
    '';

    files.".config/btop/themes/${theme.name}.theme".text = btopTheme + "\n";

    # Read-only symlink: btop must not try to save it on exit.
    files.".config/btop/btop.conf".text = ''
      color_theme = "${theme.name}"
      theme_background = false
      save_config_on_exit = false
    '';
  };

  den.schema.user.includes = [ den.aspects.common-utils ];
}
