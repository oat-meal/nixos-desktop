{ pkgs, ... }:

{
  ########################################
  ## User packages (Home Manager)
  ##
  ## Only applied to "oat" via
  ##   home/oat/default.nix
  ########################################

  home.packages = with pkgs; [
    ######## Unstable desktop apps ########
    pkgs.unstable.discord  # Voice/video chat and messaging (from unstable for latest fixes)

    ######## Stable GUI apps ########
    mpv                    # Lightweight media player
    rustdesk-flutter       # Remote desktop client
    waypaper               # GUI wallpaper manager for Wayland (swaybg backend)

    ######## User tools ########
    # wl-clipboard, htop, ripgrep provided by system packages (core/niri)
    unzip                  # ZIP archive extraction
    gh                     # GitHub CLI
    yt-dlp                 # YouTube video downloader
    appimage-run           # Run AppImages on NixOS

    ######## Hardware support ########
    libusb1                # USB device access library
  ];
}
