{ config, pkgs, lib, ... }:

{
  ################################
  ## Waybar - Status Bar for Niri
  ## Catppuccin Macchiato themed
  ################################

  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        # Required: layer must be "top" for niri visibility
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        margin-top = 4;
        margin-left = 8;
        margin-right = 8;

        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];

        modules-center = [
          "clock"
        ];

        modules-right = [
          "tray"
          "custom/caffeine"
          "custom/vpn"
          "pulseaudio"
          "network"
          "battery"
          "cpu"
          "memory"
          "custom/power"
        ];

        ################################
        ## Module configurations
        ################################

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
            urgent = "";
          };
          on-click = "activate";
        };

        "niri/window" = {
          format = "{title}";
          max-length = 50;
          rewrite = {
            "(.*) - LibreWolf" = " $1";
            "Alacritty" = " Terminal";
          };
        };

        clock = {
          format = "  {:%H:%M}";
          format-alt = "  {:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            weeks-pos = "right";
            format = {
              months = "<span color='#cad3f5'><b>{}</b></span>";
              days = "<span color='#939ab7'>{}</span>";
              weeks = "<span color='#8aadf4'>W{}</span>";
              weekdays = "<span color='#f5a97f'>{}</span>";
              today = "<span color='#c6a0f6'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          format = "  {usage}%";
          tooltip = true;
          interval = 2;
        };

        memory = {
          format = "  {}%";
          tooltip-format = "{used:0.1f}GB / {total:0.1f}GB";
          interval = 2;
        };

        network = {
          format-wifi = "  {signalStrength}%";
          format-ethernet = "  {ipaddr}";
          format-disconnected = "  Offline";
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
          on-click = "nm-connection-editor";
        };

        battery = {
          interval = 10;
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon}  {capacity}%";
          format-charging = "  {capacity}%";
          format-plugged = "  {capacity}%";
          format-icons = [ "" "" "" "" "" ];
          tooltip-format = "{timeTo}\n{power:.1f}W";
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-muted = "  Muted";
          format-icons = {
            default = [ "" "" "" ];
            headphone = "";
            headset = "";
          };
          on-click = "pavucontrol";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          scroll-step = 5;
        };

        tray = {
          icon-size = 18;
          spacing = 10;
        };

        "custom/caffeine" = {
          exec = "~/.local/bin/waybar-caffeine";
          return-type = "json";
          interval = 2;
          on-click = "~/.local/bin/waybar-caffeine toggle";
        };

        "custom/vpn" = {
          exec = "~/.local/bin/waybar-vpn";
          return-type = "json";
          interval = 5;
          on-click = "~/.local/bin/waybar-vpn toggle";
        };

        "custom/power" = {
          format = "";
          tooltip = true;
          tooltip-format = "Power Menu";
          on-click = "wlogout";
        };
      };
    };

    ################################
    ## Catppuccin Macchiato Styling
    ################################
    style = ''
      /* Catppuccin Macchiato palette */
      @define-color base #24273a;
      @define-color mantle #1e2030;
      @define-color crust #181926;
      @define-color surface0 #363a4f;
      @define-color surface1 #494d64;
      @define-color surface2 #5b6078;
      @define-color overlay0 #6e738d;
      @define-color overlay1 #8087a2;
      @define-color subtext0 #a5adcb;
      @define-color subtext1 #b8c0e0;
      @define-color text #cad3f5;
      @define-color mauve #c6a0f6;
      @define-color red #ed8796;
      @define-color peach #f5a97f;
      @define-color yellow #eed49f;
      @define-color green #a6da95;
      @define-color teal #8bd5ca;
      @define-color blue #8aadf4;
      @define-color lavender #b7bdf8;
      @define-color pink #f5bde6;

      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: alpha(@base, 0.9);
        color: @text;
        border-radius: 10px;
        border: 2px solid @mauve;
      }

      tooltip {
        background-color: @base;
        color: @text;
        border: 2px solid @mauve;
        border-radius: 8px;
      }

      tooltip label {
        color: @text;
        padding: 4px;
      }

      #workspaces {
        margin-left: 8px;
      }

      #workspaces button {
        padding: 0 8px;
        color: @overlay0;
        background: transparent;
        border: none;
        border-radius: 4px;
        margin: 4px 2px;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background-color: @surface0;
        color: @text;
      }

      #workspaces button.active {
        color: @mauve;
        background-color: @surface0;
      }

      #workspaces button.urgent {
        color: @red;
        animation: blink 0.5s linear infinite alternate;
      }

      @keyframes blink {
        to {
          background-color: @red;
          color: @base;
        }
      }

      #window {
        padding: 0 12px;
        color: @subtext0;
      }

      #clock {
        padding: 0 16px;
        color: @mauve;
        font-weight: bold;
      }

      #cpu,
      #memory,
      #network,
      #battery,
      #pulseaudio,
      #tray {
        padding: 0 12px;
        margin: 4px 2px;
        border-radius: 6px;
        background-color: @surface0;
      }

      #cpu {
        color: @blue;
      }

      #memory {
        color: @green;
      }

      #network {
        color: @teal;
      }

      #network.disconnected {
        color: @red;
      }

      #battery {
        color: @green;
      }

      #battery.charging {
        color: @green;
      }

      #battery.plugged {
        color: @mauve;
      }

      #battery.warning:not(.charging) {
        color: @yellow;
      }

      #battery.critical:not(.charging) {
        color: @red;
        animation: blink 0.5s linear infinite alternate;
      }

      #pulseaudio {
        color: @yellow;
      }

      #pulseaudio.muted {
        color: @overlay0;
      }

      #tray {
        background-color: transparent;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: @red;
      }

      #custom-power {
        padding: 0 14px;
        margin: 4px 8px 4px 2px;
        color: @red;
        border-radius: 6px;
        background-color: @surface0;
      }

      #custom-power:hover {
        background-color: @red;
        color: @base;
      }

      #custom-caffeine {
        padding: 0 12px;
        margin: 4px 2px;
        border-radius: 6px;
        background-color: @surface0;
      }

      #custom-caffeine.active {
        color: @peach;
      }

      #custom-caffeine.inactive {
        color: @overlay0;
      }

      #custom-vpn {
        padding: 0 12px;
        margin: 4px 2px;
        border-radius: 6px;
        background-color: @surface0;
      }

      #custom-vpn.connected {
        color: @green;
      }

      #custom-vpn.disconnected {
        color: @overlay0;
      }
    '';
  };
}
