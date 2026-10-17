{
  inputs,
  den,
  ...
}:

{
  imports = [ inputs.den.flakeModule ];
  den.default.includes = [ den.batteries.hostname ];
}
