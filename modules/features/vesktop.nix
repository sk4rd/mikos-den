{ config, lib, ... }:

let
  inherit (config) theme;
  c = theme.colors;

  # Discord redefines its variables on each nested theme class, so `:root` alone is not enough.
  quickCss = ''
    :root, .theme-dark, .theme-darker, .theme-midnight {
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "  --${k}: ${v} !important;\n") vars)}}
  '';

  vars = {
    background-base-lowest = c.bgDim;
    background-base-lower = c.bg;
    background-base-low = c.surface;
    background-surface-high = c.surface;
    background-surface-higher = c.overlay;
    background-surface-highest = c.overlay;
    background-brand = c.accent;
    modal-background = c.surface;
    input-background-default = c.surface;

    text-default = c.fg;
    text-strong = c.fgBright;
    text-muted = c.dim;
    text-subtle = c.dim;
    text-brand = c.accent;
    text-link = c.accent;
    text-code = c.syntax.string;
    text-feedback-critical = c.error;
    text-feedback-positive = c.success;
    text-feedback-warning = c.warning;

    interactive-text-default = c.subtle;
    interactive-text-hover = c.fg;
    interactive-text-active = c.fgBright;

    icon-default = c.subtle;
    icon-strong = c.fg;
    icon-muted = c.dim;
    icon-subtle = c.dim;
    channel-icon = c.dim;

    border-subtle = c.overlay;
    border-muted = c.overlay;
    border-normal = c.overlay;
    border-strong = c.muted;
    border-focus = c.accent;

    # The accent is light, so text on it is dark.
    control-primary-background-default = c.accent;
    control-primary-background-hover = c.lightBlue;
    control-primary-background-active = c.lightBlue;
    control-primary-text-default = c.bg;
    control-primary-text-hover = c.bg;
    control-primary-text-active = c.bg;

    font-primary = theme.fonts.ui.name;
    font-code = theme.fonts.mono.name;
  };
in
{
  den.aspects.vesktop.hjem = { pkgs, ... }: {
    packages = [ pkgs.vesktop ];

    files.".config/vesktop/settings/quickCss.css" = {
      text = quickCss;
      clobber = true;
    };
  };
}
