# KDE Plasma 6 → Niri Migration Plan

> **Historical document** — This migration was completed in March 2026. File paths
> reference the pre-restructure `modules/` layout which no longer exists. Current
> configuration lives in `hosts/common/optional/desktop/niri/` (NixOS) and
> `home/common/optional/desktop/niri/` (Home Manager). Kept for reference only.

This document outlines the migration from KDE Plasma 6 to Niri compositor on workstation-nixos (formerly desktop-nixos).

## Project Overview

| Aspect | Choice |
|--------|--------|
| **Compositor** | Niri (via niri-flake for latest features) |
| **Installation** | niri-flake with Nix-native configuration |
| **Login Manager** | greetd + tuigreet (Catppuccin themed) |
| **File Manager** | Yazi (TUI with image preview + mouse support) |
| **KDE Fallback** | Retained until Niri validated |

## Complete Desktop Stack

| Component | Tool | Package/Config |
|-----------|------|----------------|
| Compositor | Niri | `niri-flake` (unstable) |
| Status Bar | Waybar | `programs.waybar` |
| App Launcher | Fuzzel | `programs.fuzzel` |
| File Manager | Yazi | `programs.yazi` + plugins |
| Wallpaper | swaybg | `spawn-at-startup` |
| Notifications | mako | `services.mako` |
| Lock Screen | swaylock-effects | `programs.swaylock` |
| Idle Daemon | swayidle | `services.swayidle` |
| Login Manager | greetd + tuigreet | `services.greetd` |
| Screenshots | Niri built-in + satty | annotation tool |
| Clipboard | wl-clipboard + cliphist | clipboard history |
| Power Menu | wlogout | logout/shutdown UI |
| Polkit Agent | lxqt-policykit | auth prompts |
| XWayland | xwayland-satellite | X11 app compat |
| Portals | xdg-desktop-portal-gnome | screen sharing |

## Module Structure

```
/etc/nixos/
├── flake.nix                    # Add niri-flake input
├── hosts/desktop/
│   └── default.nix              # Keep KDE, add niri session
├── modules/
│   └── desktop/
│       ├── niri/
│       │   ├── default.nix      # NixOS module (greetd, portals, etc)
│       │   └── home.nix         # Home-manager (niri config, tools)
│       ├── waybar.nix           # Status bar config
│       ├── fuzzel.nix           # App launcher
│       ├── yazi.nix             # File manager
│       ├── mako.nix             # Notifications
│       └── lock-screen.nix      # swaylock + swayidle
└── home/
    └── desktop-user.nix         # Import niri modules
```

## Implementation Phases

### Phase 1: Foundation
- [ ] Add niri-flake to flake.nix inputs
- [ ] Create `modules/desktop/niri/default.nix` (NixOS module)
- [ ] Create `modules/desktop/niri/home.nix` (Home-manager config)
- [ ] Basic Niri configuration with keybindings
- [ ] Test Niri session from TTY

### Phase 2: Essential Tools
- [ ] Configure Waybar with workspace indicator, clock, system tray
- [ ] Set up Fuzzel launcher with Catppuccin theme
- [ ] Configure Yazi with image preview and mouse navigation
- [ ] Add swaybg for wallpaper

### Phase 3: Session Management
- [ ] Configure swaylock-effects with blur/screenshot
- [ ] Set up swayidle for automatic locking
- [ ] Configure greetd + tuigreet with Catppuccin colors
- [ ] Add mako notifications

### Phase 4: Polish & Integration
- [ ] Full Catppuccin Macchiato theming across all tools
- [ ] Clipboard history (cliphist)
- [ ] Screenshot workflow (satty annotations)
- [ ] wlogout power menu
- [ ] XWayland satellite for legacy apps
- [ ] Portal integration for screen sharing

### Phase 5: Validation & Cleanup
- [ ] Test all gaming workflows (Steam, Lutris, GameScope)
- [ ] Test DisplayLink monitors
- [ ] Validate Bluetooth/audio
- [ ] Remove KDE Plasma (optional)
- [ ] Update documentation

---

## Configuration Details

### flake.nix Additions

```nix
{
  inputs = {
    # ... existing inputs ...

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, niri-flake, ... }@inputs: {
    nixosConfigurations.desktop-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop
        niri-flake.nixosModules.niri
        home-manager.nixosModules.home-manager
        {
          nixpkgs.overlays = [ niri-flake.overlays.niri ];
          home-manager.sharedModules = [ niri-flake.homeModules.niri ];
        }
      ];
    };
  };
}
```

### modules/desktop/niri/default.nix (NixOS)

```nix
{ config, pkgs, lib, ... }:

{
  # Enable Niri compositor
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  # XWayland support via satellite
  environment.systemPackages = with pkgs; [
    xwayland-satellite
  ];

  # Portal for screen sharing, file dialogs
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # PAM for swaylock (required!)
  security.pam.services.swaylock = {};

  # Polkit agent
  security.polkit.enable = true;

  # greetd login manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --time-format '%Y-%m-%d %H:%M' --greeting 'Welcome to NixOS' --asterisks --remember --remember-user-session --theme 'border=mauve;text=text;prompt=mauve;time=subtext0;action=peach;button=surface0;container=base;input=surface0'";
        user = "greeter";
      };
    };
  };

  # Prevent console spam on greetd tty
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
```

### modules/desktop/niri/home.nix (Home-manager)

```nix
{ config, pkgs, lib, ... }:

{
  programs.niri = {
    settings = {
      # Prefer server-side decorations
      prefer-no-csd = true;

      # Input configuration
      input = {
        keyboard.xkb.layout = "us";
        mouse.accel-speed = 0.0;
        touchpad = {
          tap = true;
          natural-scroll = true;
        };
        focus-follows-mouse.enable = true;
      };

      # Layout
      layout = {
        gaps = 8;
        center-focused-column = "never";

        border = {
          enable = true;
          width = 2;
          active.color = "#c6a0f6";   # Mauve
          inactive.color = "#494d64"; # Surface1
        };

        focus-ring.enable = false;
      };

      # Startup applications
      spawn-at-startup = [
        { command = [ "waybar" ]; }
        { command = [ "swaybg" "-i" "/home/oat/.config/wallpaper.jpg" "-m" "fill" ]; }
        { command = [ "mako" ]; }
        { command = [ "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent" ]; }
        { command = [ "wl-paste" "--watch" "cliphist" "store" ]; }
      ];

      # Keybindings
      binds = with config.lib.niri.actions; {
        # App launchers
        "Mod+D".action = spawn "fuzzel";
        "Mod+Return".action = spawn "alacritty";
        "Mod+E".action = spawn "alacritty" "-e" "yazi";

        # Window management
        "Mod+Q".action = close-window;
        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+Space".action = toggle-window-floating;

        # Focus
        "Mod+H".action = focus-column-left;
        "Mod+J".action = focus-window-down;
        "Mod+K".action = focus-window-up;
        "Mod+L".action = focus-column-right;

        # Move windows
        "Mod+Shift+H".action = move-column-left;
        "Mod+Shift+J".action = move-window-down;
        "Mod+Shift+K".action = move-window-up;
        "Mod+Shift+L".action = move-column-right;

        # Workspaces
        "Mod+1".action = focus-workspace 1;
        "Mod+2".action = focus-workspace 2;
        "Mod+3".action = focus-workspace 3;
        "Mod+4".action = focus-workspace 4;
        "Mod+5".action = focus-workspace 5;

        "Mod+Shift+1".action = move-column-to-workspace 1;
        "Mod+Shift+2".action = move-column-to-workspace 2;
        "Mod+Shift+3".action = move-column-to-workspace 3;
        "Mod+Shift+4".action = move-column-to-workspace 4;
        "Mod+Shift+5".action = move-column-to-workspace 5;

        # Column sizing
        "Mod+Minus".action = set-column-width "-10%";
        "Mod+Equal".action = set-column-width "+10%";

        # Screenshots
        "Print".action = screenshot;
        "Mod+Print".action = screenshot-screen;
        "Mod+Shift+Print".action = screenshot-window;

        # Lock/Exit
        "Mod+Escape".action = spawn "swaylock";
        "Mod+Shift+E".action = quit;

        # Power menu
        "Mod+Shift+P".action = spawn "wlogout";

        # Clipboard history
        "Mod+V".action = spawn "sh" "-c" "cliphist list | fuzzel -d | cliphist decode | wl-copy";
      };

      # Window rules
      window-rules = [
        {
          matches = [{ app-id = "^firefox$"; }];
          open-maximized = true;
        }
        {
          matches = [{ app-id = "^steam$"; }];
          open-floating = true;
        }
        {
          matches = [{ app-id = "^pavucontrol$"; }];
          open-floating = true;
          default-floating-position = { x = 100; y = 100; relative-to = "top-right"; };
        }
      ];
    };
  };
}
```

### modules/desktop/waybar.nix

```nix
{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";  # Required for niri
        position = "top";
        height = 32;
        spacing = 8;

        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "tray"
        ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };

        "niri/window" = {
          format = "{}";
          max-length = 50;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        cpu = {
          format = " {usage}%";
          tooltip = true;
        };

        memory = {
          format = " {}%";
        };

        network = {
          format-wifi = " {signalStrength}%";
          format-ethernet = " {ipaddr}";
          format-disconnected = "⚠ Disconnected";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " muted";
          format-icons = {
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(36, 39, 58, 0.9);
        color: #cad3f5;
        border-bottom: 2px solid #c6a0f6;
      }

      #workspaces button {
        padding: 0 8px;
        color: #6e738d;
        background: transparent;
        border: none;
      }

      #workspaces button.active {
        color: #c6a0f6;
      }

      #clock, #cpu, #memory, #network, #pulseaudio, #tray {
        padding: 0 12px;
      }

      #clock {
        color: #c6a0f6;
        font-weight: bold;
      }
    '';
  };
}
```

### modules/desktop/fuzzel.nix

```nix
{ config, pkgs, lib, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
        terminal = "alacritty -e";
        layer = "overlay";
        width = 50;
        lines = 12;
        horizontal-pad = 20;
        vertical-pad = 10;
        inner-pad = 5;
      };
      colors = {
        # Catppuccin Macchiato
        background = "24273add";
        text = "cad3f5ff";
        match = "c6a0f6ff";
        selection = "363a4fff";
        selection-text = "cad3f5ff";
        selection-match = "c6a0f6ff";
        border = "c6a0f6ff";
      };
      border = {
        width = 2;
        radius = 8;
      };
    };
  };
}
```

### modules/desktop/yazi.nix

```nix
{ config, pkgs, lib, ... }:

{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };

      preview = {
        image_filter = "lanczos3";
        image_quality = 90;
        max_width = 600;
        max_height = 900;
        cache_dir = "";
        ueberzug_scale = 1;
        ueberzug_offset = [ 0 0 0 0 ];
      };

      opener = {
        edit = [
          { run = ''nvim "$@"''; block = true; }
        ];
        open = [
          { run = ''xdg-open "$@"''; orphan = true; }
        ];
        reveal = [
          { run = ''xdg-open "$(dirname "$1")"''; orphan = true; }
        ];
      };

      open = {
        rules = [
          { name = "*/"; use = [ "edit" "open" "reveal" ]; }
          { mime = "text/*"; use = [ "edit" ]; }
          { mime = "image/*"; use = [ "open" "reveal" ]; }
          { mime = "video/*"; use = [ "open" "reveal" ]; }
          { mime = "audio/*"; use = [ "open" "reveal" ]; }
          { mime = "application/pdf"; use = [ "open" "reveal" ]; }
          { mime = "*"; use = [ "open" "reveal" ]; }
        ];
      };
    };

    # Enable mouse support
    keymap = {
      manager.prepend_keymap = [
        { on = [ "<C-n>" ]; run = "create"; desc = "Create file/dir"; }
        { on = [ "." ]; run = "hidden toggle"; desc = "Toggle hidden"; }
      ];
    };

    # Catppuccin Macchiato theme
    theme = {
      manager = {
        cwd = { fg = "#c6a0f6"; };
        hovered = { fg = "#24273a"; bg = "#c6a0f6"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#eed49f"; bold = true; };
        find_position = { fg = "#f5bde6"; bg = "reset"; bold = true; };
        marker_selected = { fg = "#a6da95"; bg = "#a6da95"; };
        marker_copied = { fg = "#eed49f"; bg = "#eed49f"; };
        marker_cut = { fg = "#ed8796"; bg = "#ed8796"; };
        tab_active = { fg = "#24273a"; bg = "#c6a0f6"; };
        tab_inactive = { fg = "#cad3f5"; bg = "#363a4f"; };
        border = { fg = "#6e738d"; };
      };
      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#363a4f"; bg = "#363a4f"; };
        mode_normal = { fg = "#24273a"; bg = "#8aadf4"; bold = true; };
        mode_select = { fg = "#24273a"; bg = "#a6da95"; bold = true; };
        mode_unset = { fg = "#24273a"; bg = "#f5a97f"; bold = true; };
        progress_label = { fg = "#cad3f5"; bold = true; };
        progress_normal = { fg = "#8aadf4"; bg = "#363a4f"; };
        progress_error = { fg = "#ed8796"; bg = "#363a4f"; };
        permissions_t = { fg = "#8aadf4"; };
        permissions_r = { fg = "#eed49f"; };
        permissions_w = { fg = "#ed8796"; };
        permissions_x = { fg = "#a6da95"; };
        permissions_s = { fg = "#6e738d"; };
      };
      input = {
        border = { fg = "#8aadf4"; };
        title = {};
        value = {};
        selected = { reversed = true; };
      };
      select = {
        border = { fg = "#8aadf4"; };
        active = { fg = "#f5bde6"; };
        inactive = {};
      };
      tasks = {
        border = { fg = "#8aadf4"; };
        title = {};
        hovered = { underline = true; };
      };
      which = {
        mask = { bg = "#363a4f"; };
        cand = { fg = "#8bd5ca"; };
        rest = { fg = "#939ab7"; };
        desc = { fg = "#f5bde6"; };
        separator = "  ";
        separator_style = { fg = "#494d64"; };
      };
      help = {
        on = { fg = "#f5bde6"; };
        exec = { fg = "#8bd5ca"; };
        desc = { fg = "#939ab7"; };
        hovered = { bg = "#494d64"; bold = true; };
        footer = { fg = "#363a4f"; bg = "#cad3f5"; };
      };
      filetype = {
        rules = [
          { mime = "image/*"; fg = "#8bd5ca"; }
          { mime = "video/*"; fg = "#eed49f"; }
          { mime = "audio/*"; fg = "#eed49f"; }
          { mime = "application/zip"; fg = "#f5bde6"; }
          { mime = "application/gzip"; fg = "#f5bde6"; }
          { mime = "application/x-tar"; fg = "#f5bde6"; }
          { mime = "application/pdf"; fg = "#ed8796"; }
          { name = "*"; fg = "#cad3f5"; }
          { name = "*/"; fg = "#8aadf4"; }
        ];
      };
    };
  };

  # Required for image preview in terminal
  home.packages = with pkgs; [
    ueberzugpp   # Image preview backend
    ffmpegthumbnailer  # Video thumbnails
    poppler      # PDF preview
    fd           # Fast find
    ripgrep      # Fast grep
    fzf          # Fuzzy finder
    jq           # JSON preview
    file         # File type detection
  ];
}
```

### modules/desktop/mako.nix

```nix
{ config, pkgs, lib, ... }:

{
  services.mako = {
    enable = true;

    # Catppuccin Macchiato
    backgroundColor = "#24273a";
    textColor = "#cad3f5";
    borderColor = "#c6a0f6";
    progressColor = "over #363a4f";

    borderRadius = 8;
    borderSize = 2;
    padding = "15";
    margin = "10";

    defaultTimeout = 5000;
    layer = "overlay";

    font = "JetBrainsMono Nerd Font 11";

    extraConfig = ''
      [urgency=low]
      border-color=#8aadf4

      [urgency=high]
      border-color=#ed8796
      default-timeout=0
    '';
  };
}
```

### modules/desktop/lock-screen.nix

```nix
{ config, pkgs, lib, ... }:

{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # Appearance
      screenshots = true;
      clock = true;
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 7;

      # Effects
      effect-blur = "7x5";
      effect-vignette = "0.5:0.5";
      fade-in = 0.2;

      # Catppuccin Macchiato colors
      color = "24273a";
      bs-hl-color = "ed8796";
      key-hl-color = "a6da95";
      caps-lock-bs-hl-color = "ed8796";
      caps-lock-key-hl-color = "f5a97f";

      inside-color = "24273a";
      inside-clear-color = "24273a";
      inside-ver-color = "24273a";
      inside-wrong-color = "24273a";

      line-color = "24273a";
      line-clear-color = "24273a";
      line-ver-color = "24273a";
      line-wrong-color = "24273a";

      ring-color = "8aadf4";
      ring-clear-color = "f5a97f";
      ring-ver-color = "8aadf4";
      ring-wrong-color = "ed8796";

      separator-color = "24273a";
      text-color = "cad3f5";
      text-clear-color = "cad3f5";
      text-ver-color = "cad3f5";
      text-wrong-color = "ed8796";

      # Font
      font = "JetBrainsMono Nerd Font";
      font-size = 24;

      # Date/time format
      timestr = "%H:%M";
      datestr = "%A, %B %d";
    };
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
      {
        timeout = 600;
        command = "${pkgs.niri-unstable}/bin/niri msg action power-off-monitors";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock-effects}/bin/swaylock -f";
      }
    ];
  };
}
```

---

## Packages to Add

### System Packages (modules/system-packages.nix)

```nix
# Add to environment.systemPackages
xwayland-satellite  # XWayland for legacy apps
wl-clipboard        # Clipboard utilities
wlogout             # Power menu
brightnessctl       # Brightness control (for laptop)
playerctl           # Media controls
networkmanagerapplet # nm-applet for tray
blueman             # Bluetooth (already have)
satty               # Screenshot annotation
```

### User Packages (modules/user-packages.nix or yazi.nix)

```nix
# For Yazi image preview
ueberzugpp
ffmpegthumbnailer
poppler
fd
jq

# Clipboard history
cliphist
```

---

## Migration Checklist

### Pre-Migration
- [ ] Backup current KDE configuration
- [ ] Document any custom KDE shortcuts
- [ ] Note any KDE-specific apps in use

### Testing Phase
- [ ] Build configuration: `sudo nixos-rebuild dry-build --flake /etc/nixos#desktop-nixos`
- [ ] Switch to new config: `sudo nixos-rebuild switch --flake /etc/nixos#desktop-nixos`
- [ ] Test Niri from TTY first (Ctrl+Alt+F2, login, run `niri-session`)
- [ ] Verify all keybindings work
- [ ] Test gaming (Steam, Lutris)
- [ ] Test audio/Bluetooth
- [ ] Test DisplayLink if applicable

### Post-Validation
- [ ] Configure greetd to default to Niri
- [ ] Remove KDE packages (optional)
- [ ] Update CLAUDE.md documentation

---

## Troubleshooting

### Niri Won't Start from Login Manager
Known issue with some greetd/GDM configurations. Test from TTY first:
```bash
# Switch to TTY2
Ctrl+Alt+F2
# Login and start Niri
niri-session
```

### Swaylock Won't Unlock
Ensure PAM is configured:
```nix
security.pam.services.swaylock = {};
```

### No Image Preview in Yazi
Ensure terminal supports graphics protocol. Alacritty doesn't support Sixel, so we use ueberzugpp which works via a separate window overlay.

### XWayland Apps Not Working
Ensure xwayland-satellite is in spawn-at-startup or starts automatically via systemd.

---

## References

- [Niri GitHub](https://github.com/niri-wm/niri)
- [niri-flake](https://github.com/sodiboo/niri-flake)
- [Niri NixOS Wiki](https://wiki.nixos.org/wiki/Niri)
- [Yazi NixOS Wiki](https://wiki.nixos.org/wiki/Yazi)
- [awesome-niri](https://github.com/niri-wm/awesome-niri)
- [Catppuccin](https://github.com/catppuccin/catppuccin)
