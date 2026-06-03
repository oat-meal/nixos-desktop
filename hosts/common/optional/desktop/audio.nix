# Audio configuration
# PipeWire stack with ALSA, PulseAudio, and JACK support

{ pkgs, ... }:

{
  # RTKit for realtime audio priority
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  environment.systemPackages = with pkgs; [
    pavucontrol
    pamixer
    pulseaudio
    alsa-utils
    helvum
  ];
}
