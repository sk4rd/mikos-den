let
  lanBase = "192.168.178";
  lanPrefixLength = "24";
in
{
  inherit lanPrefixLength;
  nasLanAddress = "${lanBase}.3";
  lanPrefix = "${lanBase}.0/${lanPrefixLength}";
  routerAddress = "${lanBase}.1";
}
