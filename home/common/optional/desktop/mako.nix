{ config, pkgs, lib, ... }:

{
  ################################
  ## Mako - Notification Daemon
  ## Catppuccin Macchiato themed
  ################################

  services.mako = {
    enable = true;

    settings = {
      # Catppuccin Macchiato colors
      background-color = "#24273a";
      text-color = "#cad3f5";
      border-color = "#c6a0f6";
      progress-color = "over #363a4f";

      # Appearance
      border-radius = 10;
      border-size = 2;
      padding = "15";
      margin = "10";
      width = 350;
      height = 150;

      # Behavior
      default-timeout = 5000;
      layer = "overlay";
      anchor = "top-right";
      sort = "-time";
      max-visible = 5;
      max-icon-size = 48;

      # Font
      font = "JetBrainsMono Nerd Font 11";

      # Icons
      icons = true;
      icon-path = "${pkgs.catppuccin-papirus-folders}/share/icons/Papirus-Dark";
    };

    # Extra configuration for urgency levels and app-specific rules
    extraConfig = ''
      [urgency=low]
      border-color=#8aadf4
      default-timeout=3000

      [urgency=normal]
      border-color=#c6a0f6
      default-timeout=5000

      [urgency=high]
      border-color=#ed8796
      default-timeout=0

      [app-name=Spotify]
      default-timeout=3000
      group-by=app-name

      [app-name=discord]
      default-timeout=5000
      group-by=app-name

      [app-name=Steam]
      default-timeout=5000
      group-by=app-name
    '';
  };
}
