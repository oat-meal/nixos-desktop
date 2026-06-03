{ config, pkgs, inputs, ... }:

{
  ################################
  ## Home Manager identity
  ################################
  home.username = "oat";
  home.homeDirectory = "/home/oat";
  home.stateVersion = "25.05";

  ################################
  ## Home-Manager-specific nixpkgs config
  ################################
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = pkg:
        builtins.elem (pkgs.lib.getName pkg) [
          "discord"
        ];
    };
  };

  ################################
  ## Imports: user-only modules
  ################################
  imports = [
    ../common/optional/user-packages.nix
    ../common/optional/theme.nix

    # Niri desktop environment (Home Manager configs)
    ../common/optional/desktop/niri/home.nix
    ../common/optional/desktop/waybar.nix
    ../common/optional/desktop/fuzzel.nix
    ../common/optional/desktop/yazi.nix
    ../common/optional/desktop/mako.nix
    ../common/optional/desktop/lock-screen.nix
    ../common/optional/desktop/wlogout.nix
  ];

  ################################
  ## Shell & editor
  ################################
  programs.neovim.enable = true;
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "JetBrainsMono Nerd Font";
        size = 14.0;
      };
    };
  };

  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
    };

    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"

      # MangoHUD toggle aliases
      alias steam-hud='MANGOHUD=1 steam'
      alias steam-no-hud='MANGOHUD=0 steam'

      # Color terminal background per SSH host for visual distinction
      ssh() {
        local host="$*"
        local bg=""
        case "$host" in
          *server*)  bg="rgb:1e/1e/2e" ;;  # Catppuccin Mocha (dark purple)
          *laptop*)  bg="rgb:1a/23/2e" ;;  # Dark teal
        esac
        if [[ -n "$bg" ]]; then
          printf '\033]11;%s\033\\' "$bg"
        fi
        command ssh "$@"
        # Reset background on disconnect
        printf '\033]11;rgb:24/27/3a\033\\' # Catppuccin Macchiato base
      }
    '';
  };

  # Add ~/.local/bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # GPG agent configured system-level via yubikey module

  ################################
  ## Default browser
  ################################
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http" = [ "zen-beta.desktop" ];
    "x-scheme-handler/https" = [ "zen-beta.desktop" ];
    "x-scheme-handler/about" = [ "zen-beta.desktop" ];
    "x-scheme-handler/unknown" = [ "zen-beta.desktop" ];
    "text/html" = [ "zen-beta.desktop" ];
    "application/xhtml+xml" = [ "zen-beta.desktop" ];
    "application/x-extension-htm" = [ "zen-beta.desktop" ];
    "application/x-extension-html" = [ "zen-beta.desktop" ];
    "application/x-extension-shtml" = [ "zen-beta.desktop" ];
    "application/x-extension-xhtml" = [ "zen-beta.desktop" ];
    "application/x-extension-xht" = [ "zen-beta.desktop" ];
  };

  ################################
  ## Fightcade desktop entry (Flatpak)
  ################################
  xdg.desktopEntries.fightcade = {
    name = "Fightcade";
    comment = "Online Retro Gaming";
    exec = "flatpak run com.fightcade.Fightcade";
    icon = "com.fightcade.Fightcade";
    terminal = false;
    categories = [ "Game" ];
  };

  ################################
  ## Caffeine toggle script (inhibit idle/screen off)
  ################################
  home.file.".local/bin/waybar-caffeine" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Toggle swayidle to prevent monitor sleep
      # Used as waybar module and via keybind

      STATEFILE="$XDG_RUNTIME_DIR/caffeine-active"

      get_status() {
        if [ -f "$STATEFILE" ]; then
          echo '{"text": "󰅶", "tooltip": "Caffeine: ON (idle inhibited)", "class": "active"}'
        else
          echo '{"text": "󰛊", "tooltip": "Caffeine: OFF", "class": "inactive"}'
        fi
      }

      toggle() {
        if [ -f "$STATEFILE" ]; then
          rm "$STATEFILE"
          ${pkgs.systemd}/bin/systemctl --user start swayidle.service
          ${pkgs.libnotify}/bin/notify-send -t 3000 "Caffeine OFF" "Idle timeout re-enabled"
        else
          touch "$STATEFILE"
          ${pkgs.systemd}/bin/systemctl --user stop swayidle.service
          ${pkgs.libnotify}/bin/notify-send -t 3000 "Caffeine ON" "Monitor will stay awake"
        fi
      }

      case "$1" in
        toggle) toggle ;;
        *) get_status ;;
      esac
    '';
  };

  ################################
  ## Waybar VPN status script
  ################################
  home.file.".local/bin/waybar-vpn" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Waybar VPN status module for wgnord

      get_status() {
        # Check interface existence without sudo (avoids PAM auth failures in journal)
        if ${pkgs.iproute2}/bin/ip link show wgnord &>/dev/null; then
          ENDPOINT=$(${pkgs.iproute2}/bin/ip -j addr show wgnord 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0].addr_info[0].local // "unknown"')
          echo '{"text": "󰌾", "tooltip": "VPN: Connected\nIP: '"$ENDPOINT"'", "class": "connected"}'
        else
          echo '{"text": "󰌿", "tooltip": "VPN: Disconnected", "class": "disconnected"}'
        fi
      }

      toggle() {
        if ${pkgs.iproute2}/bin/ip link show wgnord &>/dev/null; then
          sudo ${pkgs.wgnord}/bin/wgnord disconnect
        else
          sudo ${pkgs.wgnord}/bin/wgnord connect us
        fi
      }

      case "$1" in
        toggle) toggle ;;
        *) get_status ;;
      esac
    '';
  };

  ################################
  ## Wallpaper power management
  ################################
  home.file.".local/bin/wallpaper-power-switch" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Switch between video wallpaper (AC) and static wallpaper (battery)

      VIDEO_WALLPAPER="$HOME/.config/wallpaper.mp4"
      STATIC_WALLPAPER="$HOME/.config/wallpaper.jpg"

      set_video_wallpaper() {
          ${pkgs.procps}/bin/pkill -x swaybg 2>/dev/null
          if ! ${pkgs.procps}/bin/pgrep -x mpvpaper > /dev/null; then
              ${pkgs.mpvpaper}/bin/mpvpaper -o "no-audio loop hwdec=auto panscan=1.0" "*" "$VIDEO_WALLPAPER" &
          fi
      }

      set_static_wallpaper() {
          ${pkgs.procps}/bin/pkill -x mpvpaper 2>/dev/null
          if ! ${pkgs.procps}/bin/pgrep -x swaybg > /dev/null; then
              ${pkgs.swaybg}/bin/swaybg -i "$STATIC_WALLPAPER" -m fill &
          fi
      }

      get_power_state() {
          for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD; do
              if [ -f "$ac/online" ]; then
                  cat "$ac/online" 2>/dev/null
                  return
              fi
          done
          echo "1"  # Default to AC (desktop)
      }

      if [ "$(get_power_state)" = "1" ]; then
          set_video_wallpaper
      else
          set_static_wallpaper
      fi
    '';
  };

  # Monitor power state changes via UPower
  systemd.user.services.wallpaper-power-monitor = {
    Unit = {
      Description = "Switch wallpaper based on power state";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/wallpaper-power-switch";
    };
  };

  # Poll for AC power changes (every 3 seconds)
  systemd.user.services.wallpaper-power-watch = {
    Unit = {
      Description = "Watch for power state changes";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "wallpaper-power-watch" ''
        LAST_STATE=""
        while true; do
          CURRENT=""
          for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD; do
            if [ -f "$ac/online" ]; then
              CURRENT=$(cat "$ac/online" 2>/dev/null)
              break
            fi
          done
          if [ "$CURRENT" != "$LAST_STATE" ] && [ -n "$LAST_STATE" ]; then
            sleep 1
            $HOME/.local/bin/wallpaper-power-switch
          fi
          LAST_STATE="$CURRENT"
          sleep 3
        done
      ''}";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
