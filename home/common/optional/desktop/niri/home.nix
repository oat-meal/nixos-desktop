{ config, pkgs, lib, ... }:

{
  ################################
  ## Niri Compositor - Home Manager Config
  ## User-level configuration for Niri
  ################################

  programs.niri = {
    settings = {
      ################################
      ## General preferences
      ################################
      prefer-no-csd = true;
      hotkey-overlay.skip-at-startup = true;

      ################################
      ## Input configuration
      ################################
      input = {
        keyboard = {
          xkb.layout = "us";
          repeat-delay = 300;
          repeat-rate = 50;
        };

        mouse = {
          accel-speed = 0.0;
          accel-profile = "flat";
        };

        touchpad = {
          tap = true;
          natural-scroll = true;
          accel-speed = 0.2;
        };

        # Focus follows mouse (without raising)
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };
      };

      ################################
      ## Layout configuration
      ################################
      layout = {
        gaps = 8;
        center-focused-column = "never";

        border = {
          enable = true;
          width = 2;
          active.color = "#c6a0f6";   # Catppuccin Mauve
          inactive.color = "#494d64"; # Catppuccin Surface1
        };

        focus-ring.enable = false;

        # Preset column widths (cycle with Mod+R)
        preset-column-widths = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
        ];

        # Default column width
        default-column-width = { proportion = 1.0 / 2.0; };
      };

      ################################
      ## Animations
      ################################
      animations = {
        slowdown = 1.0;

        window-open = {
          kind.easing = {
            duration-ms = 200;
            curve = "ease-out-expo";
          };
        };

        window-close = {
          kind.easing = {
            duration-ms = 150;
            curve = "ease-out-quad";
          };
        };

        workspace-switch = {
          kind.easing = {
            duration-ms = 300;
            curve = "ease-out-expo";
          };
        };
      };

      ################################
      ## Startup applications
      ################################
      spawn-at-startup = [
        { command = [ "waybar" "-c" "${config.home.homeDirectory}/.config/waybar/config" ]; }
        { command = [ "${config.home.homeDirectory}/.local/bin/wallpaper-power-switch" ]; }
        { command = [ "mako" ]; }
        { command = [ "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent" ]; }
        { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
        { command = [ "${pkgs.networkmanagerapplet}/bin/nm-applet" ]; }
      ];

      ################################
      ## Keybindings
      ################################
      binds = {
        # Application launchers
        "Mod+D".action.spawn = "fuzzel";
        "Mod+Return".action.spawn = "alacritty";
        "Mod+E".action.spawn = [ "alacritty" "-e" "yazi" ];
        "Mod+B".action.spawn = "librewolf";

        # Window management
        "Mod+Q".action.close-window = {};
        "Mod+F".action.maximize-column = {};
        "Mod+Shift+F".action.fullscreen-window = {};
        "Mod+Space".action.toggle-window-floating = {};
        "Mod+T".action.toggle-column-tabbed-display = {};

        # Focus movement (vim-style) - allow-inhibiting=false ensures these work even when apps grab input
        "Mod+H" = { allow-inhibiting = false; action.focus-column-left = {}; };
        "Mod+J" = { allow-inhibiting = false; action.focus-window-down = {}; };
        "Mod+K" = { allow-inhibiting = false; action.focus-window-up = {}; };
        "Mod+L" = { allow-inhibiting = false; action.focus-column-right = {}; };

        # Arrow key alternatives
        "Mod+Left" = { allow-inhibiting = false; action.focus-column-left = {}; };
        "Mod+Down" = { allow-inhibiting = false; action.focus-window-down = {}; };
        "Mod+Up" = { allow-inhibiting = false; action.focus-window-up = {}; };
        "Mod+Right" = { allow-inhibiting = false; action.focus-column-right = {}; };

        # Move windows
        "Mod+Shift+H".action.move-column-left = {};
        "Mod+Shift+J".action.move-window-down = {};
        "Mod+Shift+K".action.move-window-up = {};
        "Mod+Shift+L".action.move-column-right = {};

        "Mod+Shift+Left".action.move-column-left = {};
        "Mod+Shift+Down".action.move-window-down = {};
        "Mod+Shift+Up".action.move-window-up = {};
        "Mod+Shift+Right".action.move-column-right = {};

        # Workspaces - allow-inhibiting=false for reliable switching
        "Mod+1" = { allow-inhibiting = false; action.focus-workspace = 1; };
        "Mod+2" = { allow-inhibiting = false; action.focus-workspace = 2; };
        "Mod+3" = { allow-inhibiting = false; action.focus-workspace = 3; };
        "Mod+4" = { allow-inhibiting = false; action.focus-workspace = 4; };
        "Mod+5" = { allow-inhibiting = false; action.focus-workspace = 5; };
        "Mod+6" = { allow-inhibiting = false; action.focus-workspace = 6; };
        "Mod+7" = { allow-inhibiting = false; action.focus-workspace = 7; };
        "Mod+8" = { allow-inhibiting = false; action.focus-workspace = 8; };
        "Mod+9" = { allow-inhibiting = false; action.focus-workspace = 9; };

        "Mod+Shift+1".action.move-column-to-workspace = 1;
        "Mod+Shift+2".action.move-column-to-workspace = 2;
        "Mod+Shift+3".action.move-column-to-workspace = 3;
        "Mod+Shift+4".action.move-column-to-workspace = 4;
        "Mod+Shift+5".action.move-column-to-workspace = 5;
        "Mod+Shift+6".action.move-column-to-workspace = 6;
        "Mod+Shift+7".action.move-column-to-workspace = 7;
        "Mod+Shift+8".action.move-column-to-workspace = 8;
        "Mod+Shift+9".action.move-column-to-workspace = 9;

        # Workspace navigation
        "Mod+Tab".action.focus-workspace-previous = {};
        "Mod+Page_Down".action.focus-workspace-down = {};
        "Mod+Page_Up".action.focus-workspace-up = {};
        "Mod+Shift+Page_Down".action.move-column-to-workspace-down = {};
        "Mod+Shift+Page_Up".action.move-column-to-workspace-up = {};

        # Column sizing
        "Mod+Minus".action.set-column-width = "-10%";
        "Mod+Equal".action.set-column-width = "+10%";
        "Mod+R".action.switch-preset-column-width = {};
        "Mod+Shift+R".action.reset-window-height = {};

        # Scrolling
        "Mod+WheelScrollDown" = { cooldown-ms = 150; action.focus-workspace-down = {}; };
        "Mod+WheelScrollUp" = { cooldown-ms = 150; action.focus-workspace-up = {}; };
        "Mod+Shift+WheelScrollDown" = { cooldown-ms = 150; action.move-column-to-workspace-down = {}; };
        "Mod+Shift+WheelScrollUp" = { cooldown-ms = 150; action.move-column-to-workspace-up = {}; };

        # Screenshots (niri built-in)
        "Print".action.screenshot = {};
        "Mod+Print".action.screenshot-screen = {};
        "Mod+Shift+Print".action.screenshot-window = {};

        # Region screenshot to clipboard + file (Windows-style Mod+Shift+S)
        "Mod+Shift+S".action.spawn = [ "sh" "-c" "grim -g \"$(slurp)\" - | tee ~/Pictures/Screenshots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy" ];

        # Caffeine (inhibit idle)
        "Mod+Shift+C".action.spawn = [ "sh" "-c" "~/.local/bin/waybar-caffeine toggle" ];

        # Lock/Power
        "Mod+Escape".action.spawn = "swaylock";
        "Mod+Shift+E".action.quit = { skip-confirmation = false; };
        "Mod+Shift+P".action.spawn = "wlogout";

        # Clipboard history
        "Mod+V".action.spawn = [ "sh" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy" ];

        # Media keys
        "XF86AudioRaiseVolume" = { allow-when-locked = true; action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ]; };
        "XF86AudioLowerVolume" = { allow-when-locked = true; action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ]; };
        "XF86AudioMute" = { allow-when-locked = true; action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle" ]; };
        "XF86AudioMicMute" = { allow-when-locked = true; action.spawn = [ "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle" ]; };
        "XF86AudioPlay".action.spawn = [ "playerctl" "play-pause" ];
        "XF86AudioNext".action.spawn = [ "playerctl" "next" ];
        "XF86AudioPrev".action.spawn = [ "playerctl" "previous" ];

        # Overview mode (zoom out) - always works
        "Mod+O" = { allow-inhibiting = false; action.toggle-overview = {}; };
      };

      ################################
      ## Window rules
      ################################
      window-rules = [
        # Browsers open maximized
        {
          matches = [{ app-id = "librewolf"; }];
          open-maximized = true;
        }

        # Steam client floats
        {
          matches = [{ app-id = "steam"; }];
          open-floating = true;
        }

        # Steam games - use default column width, not full screen
        {
          matches = [{ app-id = "^steam_app_"; }];
          default-column-width.proportion = 0.5;
        }

        # Game launchers float
        {
          matches = [{ app-id = "lutris"; }];
          open-floating = true;
        }
        {
          matches = [{ app-id = "heroic"; }];
          open-floating = true;
        }

        # Audio/settings dialogs float
        {
          matches = [{ app-id = "^(org\\.pulseaudio\\.)?pavucontrol$"; }];
          open-floating = true;
          default-column-width.fixed = 800;
          default-window-height.fixed = 600;
        }
        {
          matches = [{ app-id = "nm-connection-editor"; }];
          open-floating = true;
        }
        {
          matches = [{ app-id = "blueman-manager"; }];
          open-floating = true;
        }

        # Picture-in-picture
        {
          matches = [{ title = "^Picture-in-Picture$"; }];
          open-floating = true;
        }
      ];

      ################################
      ## Screenshot configuration
      ################################
      screenshot-path = "~/Pictures/Screenshots/Screenshot_%Y-%m-%d_%H-%M-%S.png";
    };
  };

  ################################
  ## Ensure screenshot directory exists
  ################################
  home.file."Pictures/Screenshots/.keep".text = "";

  ################################
  ## Disable niri-flake's KDE polkit agent (we use lxqt-policykit instead)
  ################################
  systemd.user.services.niri-flake-polkit.Install.WantedBy = lib.mkForce [];
}
