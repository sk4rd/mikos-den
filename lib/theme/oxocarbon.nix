# Oxocarbon dark: raw palette data. The only file in the repo with hex colour literals;
# everything else reads the semantic roles built from it in ./default.nix.
#
# base00..base15 and blend come from nyoom-engineering/oxocarbon.nvim. Oxocarbon has no
# yellow or orange, so the missing hues (and brighter steps for the ANSI bright slots)
# come from IBM Carbon, the design system Oxocarbon is derived from.
{
  base00 = "#161616";
  base01 = "#262626";
  base02 = "#393939";
  base03 = "#525252";
  base04 = "#dde1e6";
  base05 = "#f2f4f8";
  base06 = "#ffffff";
  base07 = "#08bdba";
  base08 = "#3ddbd9";
  base09 = "#78a9ff";
  base10 = "#ee5396";
  base11 = "#33b1ff";
  base12 = "#ff7eb6";
  base13 = "#42be65";
  base14 = "#be95ff";
  base15 = "#82cfff";
  blend = "#131313";

  # IBM Carbon tokens.
  yellow30 = "#f1c21b";
  yellow20 = "#fddc69";
  orange40 = "#ff832b";
  green30 = "#6fdc8c";
  blue30 = "#a6c8ff";
  purple30 = "#d4bbff";

  # Diff backgrounds (oxocarbon.nvim).
  diffAdd = "#122f2f";
  diffChange = "#222a39";
  diffText = "#2f3f5c";
  diffDelete = "#361c28";
}
