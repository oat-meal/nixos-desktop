{ config, pkgs, lib, ... }:

{
  ################################
  ## wlogout - Power Menu
  ## Catppuccin Macchiato themed
  ################################

  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        action = "swaylock -f";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "niri msg action quit --skip-confirmation";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];

    style = ''
      /* Catppuccin Macchiato */
      @define-color base #24273a;
      @define-color surface0 #363a4f;
      @define-color text #cad3f5;
      @define-color subtext0 #a5adcb;
      @define-color mauve #c6a0f6;
      @define-color red #ed8796;
      @define-color peach #f5a97f;
      @define-color green #a6da95;
      @define-color blue #8aadf4;

      * {
        font-family: "JetBrainsMono Nerd Font";
        background-image: none;
      }

      window {
        background-color: alpha(@base, 0.9);
      }

      button {
        color: @text;
        background-color: @surface0;
        border: 2px solid transparent;
        border-radius: 12px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        margin: 8px;
      }

      button:hover {
        background-color: @mauve;
        color: @base;
        border-color: @mauve;
      }

      button:focus {
        background-color: @surface0;
        border-color: @mauve;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #lock:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #logout:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }

      #shutdown:hover {
        background-color: @red;
        border-color: @red;
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }

      #reboot:hover {
        background-color: @peach;
        border-color: @peach;
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }
    '';
  };
}
