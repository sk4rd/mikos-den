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

      # Each host decrypts with its own age key provisioned manually
      age.identityPaths = [ "/etc/age/host.key" ];

      systemd.tmpfiles.rules = [
        "d /etc/age 0700 root root -"
      ];
    };

  den.schema.host.includes = [ den.aspects.secrets ];
}
