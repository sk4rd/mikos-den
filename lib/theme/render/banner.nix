# README colour bar from the canonical theme: one block per hue on the theme background.
{ lib, theme }:
let
  c = theme.colors;
  hues = with c; [
    teal
    cyan
    sky
    blue
    purple
    pink
    magenta
    orange
    yellow
    green
  ];
  block = 80;
  height = 12;
  width = block * lib.length hues;

  rect =
    i: colour:
    ''<rect x="${toString (i * block)}" width="${toString block}" height="${toString height}" fill="${colour}"/>'';
in
''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${toString width} ${toString height}">
    <rect width="100%" height="100%" fill="${c.bg}"/>
    ${lib.concatStrings (lib.imap0 rect hues)}
  </svg>
''
