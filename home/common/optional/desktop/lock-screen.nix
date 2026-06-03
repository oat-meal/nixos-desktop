{ config, pkgs, lib, ... }:

{
  ################################
  ## Lock Screen - swaylock-effects + swayidle
  ## Catppuccin Macchiato themed
  ################################

  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;

    settings = {
      # Effects
      screenshots = true;
      clock = true;
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 7;

      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";
      fade-in = 0.2;

      # Catppuccin Macchiato colors
      color = "24273a";

      # Key highlight colors
      bs-hl-color = "ed8796";          # Red for backspace
      key-hl-color = "a6da95";         # Green for key press
      caps-lock-bs-hl-color = "ed8796";
      caps-lock-key-hl-color = "f5a97f";

      # Inside ring (locked state)
      inside-color = "24273a";
      inside-clear-color = "24273a";
      inside-caps-lock-color = "24273a";
      inside-ver-color = "24273a";
      inside-wrong-color = "24273a";

      # Line (separator between inside and ring)
      line-color = "24273a";
      line-clear-color = "24273a";
      line-caps-lock-color = "24273a";
      line-ver-color = "24273a";
      line-wrong-color = "24273a";

      # Ring colors (different states)
      ring-color = "8aadf4";            # Blue - default
      ring-clear-color = "f5a97f";      # Peach - clearing
      ring-caps-lock-color = "eed49f";  # Yellow - caps lock
      ring-ver-color = "c6a0f6";        # Mauve - verifying
      ring-wrong-color = "ed8796";      # Red - wrong password

      # Separator
      separator-color = "24273a";

      # Text colors
      text-color = "cad3f5";
      text-clear-color = "cad3f5";
      text-caps-lock-color = "cad3f5";
      text-ver-color = "cad3f5";
      text-wrong-color = "ed8796";

      # Layout text (inside the indicator)
      layout-text-color = "cad3f5";

      # Font
      font = "JetBrainsMono Nerd Font";
      font-size = 24;

      # Date/time format
      timestr = "%H:%M";
      datestr = "%A, %B %d";

      # Misc
      ignore-empty-password = true;
      show-failed-attempts = true;
    };
  };

  ################################
  ## Swayidle - Idle Management
  ################################
  services.swayidle = {
    enable = true;

    timeouts = [
      # Lock screen after 5 minutes of idle
      {
        timeout = 300;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
      # Turn off monitors after 10 minutes
      # Note: niri binary is in PATH when running under niri session
      {
        timeout = 600;
        command = "niri msg action power-off-monitors";
      }
    ];

    events = [
      # Lock before sleep (though suspend is disabled on this system)
      {
        event = "before-sleep";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
      # Lock on session lock signal
      {
        event = "lock";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
    ];
  };
}
