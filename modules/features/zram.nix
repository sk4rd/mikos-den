{ den, ... }:

{
  den.aspects.zram.nixos.zramSwap.enable = true;
  den.schema.host.includes = [ den.aspects.zram ];
}
