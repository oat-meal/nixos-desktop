{ config, pkgs, lib, inputs, ... }:

{
  ################################
  ## Niri Compositor - NixOS Module
  ## System-level configuration for Niri session
  ################################

  # Enable Niri compositor
  # Using nixpkgs niri instead of niri-flake's niri-stable to avoid build issues
  # niri-flake still provides the configuration module
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  ################################
  ## XDG Portal (screen sharing, file dialogs)
  ################################
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = [ "gnome" "gtk" ];
  };

  ################################
  ## PAM for swaylock (required for unlock)
  ################################
  security.pam.services.swaylock = {};

  ################################
  ## Polkit (authentication dialogs)
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
  ## greetd login manager with tuigreet
  ################################
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Catppuccin Macchiato theme for tuigreet
        # Colors: mauve=#c6a0f6, text=#cad3f5, subtext0=#a5adcb, base=#24273a, surface0=#363a4f, peach=#f5a97f
        command = let
          tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
        in ''
          ${tuigreet} \
            --time \
            --time-format '%Y-%m-%d %H:%M' \
            --greeting 'Welcome to NixOS' \
            --asterisks \
            --remember \
            --remember-user-session \
            --sessions /etc/greetd/sessions \
            --theme 'border=c6a0f6;text=cad3f5;prompt=c6a0f6;time=a5adcb;action=f5a97f;button=363a4f;container=24273a;input=363a4f'
        '';
        user = "greeter";
      };
    };
  };

  # Session entry for greetd
  environment.etc."greetd/sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=Scrollable tiling Wayland compositor
    Exec=niri-session
    Type=Application
  '';

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
  ## System packages for Niri ecosystem
  ################################
  environment.systemPackages = with pkgs; [
    # XWayland compatibility
    xwayland-satellite

    # Clipboard
    wl-clipboard
    cliphist

    # Screenshots
    grim      # Screenshot tool
    slurp     # Region selection
    satty     # Screenshot annotation

    # Power menu
    wlogout

    # Display configuration
    wdisplays
    wlr-randr

    # Polkit agent (lightweight)
    lxqt.lxqt-policykit

    # Wallpaper
    swaybg
    mpvpaper    # Video wallpaper (used in spawn-at-startup)

    # Media controls
    playerctl

    # Brightness (for future laptop)
    brightnessctl
  ];

  ################################
  ## Environment variables for Wayland
  ################################
  environment.sessionVariables = {
    # XWayland satellite socket
    # Note: niri-stable auto-manages DISPLAY via xwayland-satellite integration
  };
}
