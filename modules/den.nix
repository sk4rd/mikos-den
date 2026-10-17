{
  inputs,
  den,
  ...
}:

{
  imports = [ inputs.den.flakeModule ];

  den.schema.host.includes = [
    den.aspects.zram
    den.aspects.networking-base
  ];
}
