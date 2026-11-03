{
  config,
  den,
  lib,
  ...
}:

let
  c = config.theme.colors;

  colors = lib.concatStringsSep "," [
    "fg:${c.fg}"
    "bg:-1"
    "hl:${c.blue}"
    "fg+:${c.fgBright}"
    "bg+:${c.surface}"
    "hl+:${c.blue}"
    "gutter:-1"
    "border:${c.overlay}"
    "separator:${c.overlay}"
    "scrollbar:${c.overlay}"
    "info:${c.purple}"
    "prompt:${c.blue}"
    "pointer:${c.pink}"
    "marker:${c.green}"
    "spinner:${c.pink}"
    "header:${c.teal}"
    "query:${c.fg}"
  ];
in
{
  den.aspects.fzf.hjem = { pkgs, ... }: {
    packages = [ pkgs.fzf ];

    files.".config/fish/conf.d/fzf.fish".text = ''
      set -gx FZF_DEFAULT_OPTS "--color=${colors}"

      if type -q fzf
          fzf --fish | source
      end
    '';
  };

  den.schema.user.includes = [ den.aspects.fzf ];
}
