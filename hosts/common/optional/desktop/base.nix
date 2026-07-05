# Shared desktop system infrastructure (compositor-agnostic).
#
# Extracted from the former niri module so it can back MangoWM. Provides the login
# manager (greetd + tuigreet), XDG portals, polkit, gnome-keyring, and the common
# Wayland tooling. Compositor-specific bits live in the per-compositor module
# (hosts/common/optional/desktop/mango). Imported by every desktop host.

{ pkgs, ... }:

{
  ################################
  ## XDG Portal (screen sharing, file dialogs)
  ################################
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
    config.common = {
      default = [ "gnome" "gtk" ];
      # GNOME's FileChooser delegates to Nautilus (not installed) and fails silently
      # (breaks file/folder pickers, e.g. Obsidian). GTK's portal has a built-in chooser.
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  ################################
  ## Polkit (Noctalia provides the authentication agent at runtime)
  ################################
  security.polkit.enable = true;

  ################################
  ## GNOME Keyring (credential storage)
  ################################
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  # Ensure keyring socket is available early
  programs.seahorse.enable = true;

  ################################
  ## greetd login manager with tuigreet — defaults to the Mango session
  ################################
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Catppuccin Macchiato theme for tuigreet
        command = let
          tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
        in ''
          ${tuigreet} \
            --time \
            --time-format '%Y-%m-%d %H:%M' \
            --greeting 'Welcome to NixOS' \
            --asterisks \
            --remember \
            --cmd mango \
            --sessions /etc/greetd/sessions \
            --theme 'border=c6a0f6;text=cad3f5;prompt=c6a0f6;time=a5adcb;action=f5a97f;button=363a4f;container=24273a;input=363a4f'
        '';
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

  ################################
  ## Common Wayland tooling
  ################################
  environment.systemPackages = with pkgs; [
    # Clipboard
    wl-clipboard

    # Screenshots (Noctalia's screenshot actions shell out to these)
    grim
    slurp
    satty

    # Display configuration
    wdisplays
    wlr-randr

    # Wallpaper (static + video, driven by wallpaper-power-switch)
    swaybg
    mpvpaper

    # Media controls
    playerctl

    # Brightness (Noctalia brightness controls use this)
    brightnessctl
  ];
}
