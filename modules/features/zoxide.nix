{ den, ... }:

{
  den.aspects.zoxide.nixos.programs.zoxide.enable = true;

  den.schema.host.includes = [ den.aspects.zoxide ];
}
