{ den, ... }:

{
  den.aspects.ai.includes = [ (den.batteries.unfree [ "claude-code" ]) ];
  den.aspects.ai.hjem = { pkgs, ... }: {
    packages = with pkgs; [
      claude-code
      opencode
    ];
  };
}
