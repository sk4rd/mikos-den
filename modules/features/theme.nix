let
  theme = import ../../lib/theme.nix;

  themeModule = { lib, ... }: {
    options.miko.theme = lib.mkOption {
      type = lib.types.attrs;
      default = theme;
      readOnly = true;
      description = "Shared theme used by Miko's application aspects.";
    };
  };
in
{
  den.aspects.theme = {
    nixos.imports = [ themeModule ];
    hjem.imports = [ themeModule ];
  };
}
