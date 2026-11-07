# Wallpaper generated from the canonical theme: a dark field with a faint Carbon-style
# grid and one thin diagonal accent band (blue -> purple -> pink). 16:10, crops to 16:9.
{
  pkgs,
  lib,
  theme,
}:
let
  c = theme.colors;
  w = 3840;
  h = 2400;
  cell = 160;

  lines =
    axis: count: len:
    lib.concatMapStrings (
      i:
      let
        p = toString (i * cell);
      in
      if axis == "x" then
        ''<line x1="${p}" y1="0" x2="${p}" y2="${toString len}"/>''
      else
        ''<line x1="0" y1="${p}" x2="${toString len}" y2="${p}"/>''
    ) (lib.range 1 count);

  # The band runs from the bottom edge (left of centre) to the right edge.
  band = "M 1400 ${toString h} L 1436 ${toString h} L ${toString w} 840 L ${toString w} 804 Z";

  svg = pkgs.writeText "wallpaper.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString w}" height="${toString h}" viewBox="0 0 ${toString w} ${toString h}">
      <defs>
        <linearGradient id="accent" x1="1400" y1="${toString h}" x2="${toString w}" y2="804" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="${c.blue}"/>
          <stop offset="0.5" stop-color="${c.purple}"/>
          <stop offset="1" stop-color="${c.pink}"/>
        </linearGradient>
        <filter id="glow" x="-10%" y="-10%" width="120%" height="120%">
          <feGaussianBlur stdDeviation="60"/>
        </filter>
      </defs>
      <rect width="100%" height="100%" fill="${c.bg}"/>
      <g stroke="${c.surface}" stroke-width="2" opacity="0.7">
        ${lines "x" (w / cell - 1) h}
        ${lines "y" (h / cell - 1) w}
      </g>
      <path d="${band}" fill="url(#accent)" opacity="0.35" filter="url(#glow)"/>
      <path d="${band}" fill="url(#accent)"/>
    </svg>
  '';
in
pkgs.runCommand "${theme.name}-wallpaper.png" { nativeBuildInputs = [ pkgs.resvg ]; } ''
  resvg --width ${toString w} --height ${toString h} ${svg} $out
''
