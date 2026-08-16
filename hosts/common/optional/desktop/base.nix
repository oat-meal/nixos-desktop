# Shared desktop system infrastructure (compositor-agnostic).
#
# Extracted into a compositor-agnostic module so it can back MangoWM. Provides the login
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

  # PAM starts the systemd user manager with only systemd's own bin dir on PATH, and every
  # user service inherits it — including xdg-desktop-portal. GIO validates a .desktop entry by
  # resolving its Exec binary on PATH and silently discards entries it cannot resolve, so the
  # portal's AppChooser returned an empty list: every URL/file open (e.g. a link clicked inside
  # a Steam game) produced a "no apps available" dialog with nothing selectable. Zen registers
  # as `Exec=zen-beta`, a bare command name, so it was discarded along with everything else.
  # Set the PATH on the manager itself so it is in place before any portal is D-Bus activated.
  # DefaultEnvironment does not expand %u (specifiers are a unit-file feature), hence the
  # literal user name; both mango hosts are single-user.
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/wrappers/bin:/etc/profiles/per-user/oat/bin:/home/oat/.nix-profile/bin:/run/current-system/sw/bin"
  '';

  ################################
  ## Polkit (Noctalia provides the authentication agent at runtime)
  ################################
  security.polkit.enable = true;

  ################################
  ## dconf (backend for Home Manager GTK theme settings; must be enabled explicitly under MangoWM)
  ################################
  programs.dconf.enable = true;

  # Fix the boot-time Home Manager dconf activation. home-manager-<user>.service runs at
  # activation with a stripped env (no session bus), so HM wraps `dconf load` in an ephemeral
  # dbus-run-session — which can only resolve the dconf D-Bus service (ca.desrt.dconf) if
  # XDG_DATA_DIRS points at dconf's share. Without this the unit fails on `dconfSettings`.
  systemd.services."home-manager-oat".environment.XDG_DATA_DIRS = "${pkgs.dconf}/share";

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

    # Screen recording (SUPER+CTRL+S toggle in mango; VAAPI hardware encode)
    wl-screenrec

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
