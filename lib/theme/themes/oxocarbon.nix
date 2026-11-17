# The greys, the accents, the darker background and the diff backgrounds come from
# nyoom-engineering/oxocarbon.nvim, whose own base00..base15 are not Base16 slots. Oxocarbon has no
# yellow or orange, so those hues, the mid grey and the bright ANSI steps come from IBM Carbon, the
# design system Oxocarbon is derived from.
let
  base00 = "#161616";
  base01 = "#262626";
  base02 = "#393939";
  base03 = "#525252";
  base04 = "#dde1e6";
  base05 = "#f2f4f8";
  base06 = "#ffffff";
  base07 = "#ffffff";
  base08 = "#ee5396";
  base09 = "#ff832b";
  base0A = "#f1c21b";
  base0B = "#42be65";
  base0C = "#08bdba";
  base0D = "#78a9ff";
  base0E = "#be95ff";
  # Oxocarbon has no brown, and no role reads this slot.
  base0F = "#ff7eb6";
  base10 = "#131313";
  base11 = "#131313";
  base12 = "#ff7eb6";
  base13 = "#fddc69";
  base14 = "#6fdc8c";
  base15 = "#3ddbd9";
  base16 = "#a6c8ff";
  base17 = "#d4bbff";

  sky = "#33b1ff";
  lightBlue = "#82cfff";
in
{
  name = "oxocarbon";
  variant = "dark";

  inherit
    base00
    base01
    base02
    base03
    base04
    base05
    base06
    base07
    base08
    base09
    base0A
    base0B
    base0C
    base0D
    base0E
    base0F
    base10
    base11
    base12
    base13
    base14
    base15
    base16
    base17
    ;

  overrides = {
    colors = {
      dim = "#8d8d8d";
      hint = base15;
      inherit sky lightBlue;
      pink = base12;
      magenta = base08;

      # The assignments follow oxocarbon.nvim.
      syntax = {
        keyword = base0D;
        type = base0D;
        operator = base0D;
        string = base0E;
        function = base12;
        method = base0C;
        constant = base0E;
        builtin = base0C;
        namespace = base0C;
        number = lightBlue;
        property = base08;
        attribute = lightBlue;
        punctuation = base15;
        decorator = base12;
        variable = base04;
        comment = base03;
      };

      diff = {
        add = "#122f2f";
        change = "#222a39";
        text = "#2f3f5c";
        delete = "#361c28";
      };
    };

    ansiNamed.white = base04;
  };
}
