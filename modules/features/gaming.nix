{ den, ... }:

{
  den.aspects.gaming = {
    includes = [
      (den.batteries.unfree [
        "steam"
        "steam-unwrapped"
      ])
    ];

    nixos = { pkgs, ... }: {
      programs.steam = {
        enable = true;
        extraPackages = [ pkgs.mangohud ];
      };
    };

    hjem = { pkgs, ... }: {
      packages = [ pkgs.mangohud ];
    };
  };
}
