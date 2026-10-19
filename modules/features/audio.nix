{ den, ... }:

{
  den.aspects.audio.nixos.services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  den.schema.host.includes = [ den.aspects.audio ];
}
