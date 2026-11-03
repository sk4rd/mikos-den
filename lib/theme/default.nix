# The canonical theme: semantic roles over the raw palette. Consumers read `config.theme`
# (modules/theme/option.nix), never the palette file directly.
{ lib }:
let
  p = import ./oxocarbon.nix;

  hexByte = s: lib.fromHexString s;
  bare = hex: lib.removePrefix "#" hex;
  channels =
    hex:
    let
      h = bare hex;
    in
    map (i: hexByte (builtins.substring i 2 h)) [
      0
      2
      4
    ];

  ansiNamed = {
    black = p.base01;
    red = p.base10;
    green = p.base13;
    yellow = p.yellow30;
    blue = p.base09;
    magenta = p.base14;
    cyan = p.base07;
    white = p.base04;

    brightBlack = p.base03;
    brightRed = p.base12;
    brightGreen = p.green30;
    brightYellow = p.yellow20;
    brightBlue = p.blue30;
    brightMagenta = p.purple30;
    brightCyan = p.base08;
    brightWhite = p.base06;
  };
in
{
  name = "oxocarbon";
  variant = "dark";

  palette = p;

  colors = {
    # Surfaces, darkest to lightest.
    bgDim = p.blend;
    bg = p.base00;
    surface = p.base01;
    overlay = p.base02;
    muted = p.base03;
    dim = p.gray50; # between muted and subtle: inactive UI text
    subtle = p.base04;
    fg = p.base05;
    fgBright = p.base06;

    accent = p.base09;
    accentAlt = p.base14;
    selection = p.base02;
    cursor = p.base05;
    cursorText = p.base00;

    error = p.base10;
    warning = p.yellow30;
    success = p.base13;
    info = p.base09;
    hint = p.base08;

    # Hues by name.
    blue = p.base09;
    sky = p.base11;
    lightBlue = p.base15;
    teal = p.base07;
    cyan = p.base08;
    green = p.base13;
    purple = p.base14;
    pink = p.base12;
    magenta = p.base10;
    yellow = p.yellow30;
    orange = p.orange40;

    # Syntax roles, after oxocarbon.nvim.
    syntax = {
      keyword = p.base09;
      type = p.base09;
      operator = p.base09;
      string = p.base14;
      function = p.base12;
      method = p.base07;
      constant = p.base14;
      builtin = p.base07;
      namespace = p.base07;
      number = p.base15;
      property = p.base10;
      attribute = p.base15;
      punctuation = p.base08;
      decorator = p.base12;
      variable = p.base04;
      comment = p.base03;
    };

    diff = {
      add = p.diffAdd;
      change = p.diffChange;
      text = p.diffText;
      delete = p.diffDelete;
    };
  };

  inherit ansiNamed;
  ansi = with ansiNamed; [
    black
    red
    green
    yellow
    blue
    magenta
    cyan
    white
    brightBlack
    brightRed
    brightGreen
    brightYellow
    brightBlue
    brightMagenta
    brightCyan
    brightWhite
  ];

  # Packages are attribute paths into pkgs, so the theme stays pure data.
  fonts = {
    mono = {
      name = "BlexMono Nerd Font Mono";
      size = 10;
      package = [
        "nerd-fonts"
        "blex-mono"
      ];
    };
    ui = {
      name = "Inter";
      size = 10;
      package = [ "inter" ];
    };
  };

  lib = {
    # "#78a9ff" -> "78a9ff"
    inherit bare;
    # "#78a9ff" -> "120,169,255"
    rgb = hex: lib.concatMapStringsSep "," toString (channels hex);
    # "#78a9ff" -> [ 120 169 255 ]
    inherit channels;
  };
}
