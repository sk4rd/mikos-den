{ inputs, den, ... }:

{
  den.aspects.secrets.nixos = {
    imports = [ inputs.agenix.nixosModules.default ];

    # Each host decrypts with its own age key provisioned manually
    age.identityPaths = [ "/etc/age/host.key" ];

    systemd.tmpfiles.rules = [
      "d /etc/age 0700 root root -"
    ];
  };

  den.schema.host.includes = [ den.aspects.secrets ];
}
