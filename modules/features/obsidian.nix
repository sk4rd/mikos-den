{ den, ... }:
{
  den.aspects.obsidian = {
    includes = [ (den.batteries.unfree [ "obsidian" ]) ];
    # The vault is ~/Notes, synced through the NAS by the syncthing aspect.
    hjem = { pkgs, ... }: { packages = [ pkgs.obsidian ]; };
  };
}
