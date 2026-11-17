{ lib }:
let
  bare = hex: lib.removePrefix "#" hex;
  channels =
    hex:
    let
      h = bare hex;
    in
    map (i: lib.fromHexString (builtins.substring i 2 h)) [
      0
      2
      4
    ];

  byte =
    n:
    let
      h = lib.toLower (lib.toHexString n);
    in
    if n < 16 then "0${h}" else h;

  # percent of b in a, rounded per channel.
  mix =
    a: b: percent:
    "#"
    + lib.concatStrings (
      lib.zipListsWith (x: y: byte ((x * (100 - percent) + y * percent + 50) / 100)) (channels a) (
        channels b
      )
    );

  # The Base24 fallbacks, for schemes that only exist as Base16.
  fallbacks = p: {
    base10 = p.base00;
    base11 = p.base00;
    base12 = p.base08;
    base13 = p.base0A;
    base14 = p.base0B;
    base15 = p.base0C;
    base16 = p.base0D;
    base17 = p.base0E;
  };

  slots = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
    "base10"
    "base11"
    "base12"
    "base13"
    "base14"
    "base15"
    "base16"
    "base17"
  ];

  ansiOrder = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
    "brightBlack"
    "brightRed"
    "brightGreen"
    "brightYellow"
    "brightBlue"
    "brightMagenta"
    "brightCyan"
    "brightWhite"
  ];

  defaultFonts = {
    mono = {
      name = "BlexMono Nerd Font Mono";
      size = 10;
      package = [
        "nerd-fonts"
        "blex-mono"
      ];
    };
    ui = {
      name = "IBM Plex Sans";
      size = 10;
      package = [ "ibm-plex" ];
    };
  };

  generic = p: {
    colors = {
      bgDim = p.base10;
      bg = p.base00;
      surface = p.base01;
      overlay = p.base02;
      muted = p.base03;
      dim = mix p.base03 p.base04 50;
      subtle = p.base04;
      fg = p.base05;
      fgBright = p.base06;

      accent = p.base0D;
      accentAlt = p.base0E;
      selection = p.base02;
      cursor = p.base05;
      cursorText = p.base00;

      error = p.base08;
      warning = p.base0A;
      success = p.base0B;
      info = p.base0D;
      hint = p.base0C;

      blue = p.base0D;
      sky = p.base16;
      lightBlue = mix p.base16 p.base07 35;
      teal = p.base0C;
      cyan = p.base15;
      green = p.base0B;
      purple = p.base0E;
      pink = p.base17;
      magenta = mix p.base08 p.base0E 50;
      yellow = p.base0A;
      orange = p.base09;

      # Tinted Theming's styling guide, except variables, which it colours base08: that turns
      # most of a file red.
      syntax = {
        keyword = p.base0E;
        type = p.base0A;
        operator = p.base05;
        string = p.base0B;
        function = p.base0D;
        method = p.base0D;
        constant = p.base09;
        builtin = p.base0C;
        namespace = p.base0E;
        number = p.base09;
        property = p.base08;
        attribute = p.base0A;
        punctuation = p.base05;
        decorator = p.base0C;
        variable = p.base05;
        comment = p.base03;
      };

      diff = {
        add = mix p.base00 p.base0B 15;
        change = mix p.base00 p.base0E 15;
        text = mix p.base00 p.base0E 30;
        delete = mix p.base00 p.base08 15;
      };
    };

    # Black is base01 rather than the guide's base00, so black text stays visible on the background.
    ansiNamed = {
      black = p.base01;
      red = p.base08;
      green = p.base0B;
      yellow = p.base0A;
      blue = p.base0D;
      magenta = p.base0E;
      cyan = p.base0C;
      white = p.base05;

      brightBlack = p.base03;
      brightRed = p.base12;
      brightGreen = p.base14;
      brightYellow = p.base13;
      brightBlue = p.base16;
      brightMagenta = p.base17;
      brightCyan = p.base15;
      brightWhite = p.base07;
    };
  };
in
theme:
let
  given = lib.getAttrs (lib.filter (s: theme ? ${s}) slots) theme;
  palette = lib.mapAttrs (_: lib.toLower) (fallbacks given // given);
  roles = lib.recursiveUpdate (generic palette) (theme.overrides or { });
in
{
  inherit (theme) name variant;
  inherit (roles) colors ansiNamed;
  ansi = map (n: roles.ansiNamed.${n}) ansiOrder;

  # Packages are attribute paths into pkgs, so the theme stays pure data.
  fonts = lib.recursiveUpdate defaultFonts (theme.fonts or { });

  lib = {
    inherit bare channels;
    rgb = hex: lib.concatMapStringsSep "," toString (channels hex);
  };
}
