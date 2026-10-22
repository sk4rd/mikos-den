{ ... }:

{
  den.aspects.audio.nixos.services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
