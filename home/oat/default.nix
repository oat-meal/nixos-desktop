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

    # Desktop: MangoWM compositor + Noctalia shell (all desktop hosts)
    ../common/optional/desktop/yazi.nix
    ../common/optional/desktop/noctalia.nix
    ../common/optional/desktop/mango/home.nix
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
  ## Default applications
  ################################
  xdg.mimeApps.defaultApplications = {
    # Plain-text / code -> Neovim in Alacritty (see xdg.desktopEntries.nvim below).
    # Thunar hands Terminal=true entries to GLib, which can't locate a terminal
    # (Alacritty isn't in its built-in list) -> "Unable to find terminal".
    # The nvim.desktop we define runs `alacritty -e nvim` directly (Terminal=false),
    # sidestepping GLib's terminal lookup entirely.
    "text/plain" = [ "nvim.desktop" ];
    "text/markdown" = [ "nvim.desktop" ];
    "text/x-readme" = [ "nvim.desktop" ];
    "text/x-log" = [ "nvim.desktop" ];
    "text/csv" = [ "nvim.desktop" ];
    "application/json" = [ "nvim.desktop" ];
    "application/x-shellscript" = [ "nvim.desktop" ];
    "text/x-python" = [ "nvim.desktop" ];
    "text/x-nix" = [ "nvim.desktop" ];

    # Browser
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

    # Archives -> xarchiver (zip was hijacked by zathura comic-book plugin).
    # Comic-book formats (.cbz/.cbr) deliberately left on zathura for reading.
    "application/zip" = [ "xarchiver.desktop" ];
    "application/x-zip-compressed" = [ "xarchiver.desktop" ];
    "application/x-7z-compressed" = [ "xarchiver.desktop" ];
    "application/vnd.rar" = [ "xarchiver.desktop" ];
    "application/x-rar" = [ "xarchiver.desktop" ];
    "application/x-rar-compressed" = [ "xarchiver.desktop" ];
    "application/x-tar" = [ "xarchiver.desktop" ];
    "application/x-compressed-tar" = [ "xarchiver.desktop" ];      # .tar.gz / .tgz
    "application/x-bzip-compressed-tar" = [ "xarchiver.desktop" ]; # .tar.bz2
    "application/x-xz-compressed-tar" = [ "xarchiver.desktop" ];   # .tar.xz
    "application/x-zstd-compressed-tar" = [ "xarchiver.desktop" ]; # .tar.zst
    "application/gzip" = [ "xarchiver.desktop" ];
    "application/x-bzip" = [ "xarchiver.desktop" ];
    "application/x-bzip2" = [ "xarchiver.desktop" ];
    "application/x-xz" = [ "xarchiver.desktop" ];
    "application/zstd" = [ "xarchiver.desktop" ];
  };

  ################################
  ## Thunar custom actions (right-click menu)
  ################################
  # thunar-archive-plugin ships no xarchiver backend, so wire up
  # "Extract Here" as a custom action calling xarchiver directly.
  xdg.configFile."Thunar/uca.xml".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
    <action>
    	<icon>utilities-terminal</icon>
    	<name>Open Terminal Here</name>
    	<submenu></submenu>
    	<unique-id>1780432366441562-1</unique-id>
    	<command>exo-open --working-directory %f --launch TerminalEmulator</command>
    	<description>Example for a custom action</description>
    	<range></range>
    	<patterns>*</patterns>
    	<startup-notify/>
    	<directories/>
    </action>
    <action>
    	<icon>xarchiver</icon>
    	<name>Extract Here</name>
    	<submenu></submenu>
    	<unique-id>1780432366441562-2</unique-id>
    	<command>sh -c 'for f in %F; do xarchiver --extract-to="$(dirname "$f")" "$f"; done'</command>
    	<description>Extract the archive into the current folder</description>
    	<range></range>
    	<patterns>*.zip;*.7z;*.rar;*.tar;*.tar.gz;*.tgz;*.tar.bz2;*.tbz2;*.tar.xz;*.txz;*.tar.zst;*.gz;*.bz2;*.xz;*.zst;*.cbz;*.cbr;*.cb7</patterns>
    	<other-files/>
    </action>
    </actions>
  '';

  ################################
  ## Neovim launcher (opens in Alacritty)
  ################################
  # Shadows the neovim package's nvim.desktop (which is Terminal=true and fails
  # to launch from Thunar because GLib can't find a terminal). This one invokes
  # Alacritty directly, so double-click / "Open With" works from the file manager.
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    comment = "Edit text files in Neovim (Alacritty)";
    exec = "alacritty -e nvim %F";
    icon = "nvim";
    terminal = false;
    categories = [ "Utility" "TextEditor" ];
    mimeType = [
      "text/plain"
      "text/markdown"
      "text/x-readme"
      "text/x-log"
      "text/csv"
      "application/json"
      "application/x-shellscript"
      "text/x-python"
      "text/x-nix"
    ];
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
