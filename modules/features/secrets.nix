{ inputs, den, ... }:

{
  den.aspects.secrets.nixos =
    { pkgs, ... }:
    {
      imports = [ inputs.agenix.nixosModules.default ];

      environment.systemPackages = [
        pkgs.age
        inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
      ];

      # Placed by hand at install (docs/install.md); nothing generates it.
      age.identityPaths = [ "/etc/age/host.key" ];

      systemd.tmpfiles.rules = [
        "d /etc/age 0700 root root -"
      ];
    };

  den.schema.host.includes = [ den.aspects.secrets ];
}
