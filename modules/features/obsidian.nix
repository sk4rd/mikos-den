{ den, ... }:
{
  den.aspects.obsidian = {
    includes = [ (den.batteries.unfree [ "obsidian" ]) ];
    # The vault is ~/Documents/Notes, synced through the NAS by the LiveSync plugin (livesync aspect).
    hjem =
      { pkgs, ... }:
      {
        packages = [
          pkgs.obsidian
        ];

      };
  };
}
