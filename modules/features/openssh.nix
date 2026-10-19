{ den, ... }:

{
  den.aspects.openssh.nixos.services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  den.schema.host.includes = [ den.aspects.openssh ];
}
