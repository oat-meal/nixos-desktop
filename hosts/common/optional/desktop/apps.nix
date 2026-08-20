# Desktop applications
# File managers, GUI tools, and common desktop packages

{ pkgs, ... }:

{
  # Virtual filesystem for file managers
  services.gvfs.enable = true;

  environment.systemPackages = with pkgs; [
    # File management
    # The Thunar packages all moved to top-level in 26.05.
    thunar
    thunar-volman
    thunar-archive-plugin
    tumbler
    xarchiver
    trash-cli

    # Terminal
    alacritty

    # Wayland tools
    wayland
    xwayland

    # Cursors
    bibata-cursors

    # X11 compatibility
    # The xorg package set is deprecated in 26.05; these are the top-level names.
    libxcursor
    libx11
    libxrandr
    libxext
    libxcb

    # Multimedia
    ffmpeg
    libGL
    glib
    gtk3

    # GStreamer for video playback
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
    gst_all_1.gst-libav

    # Hardware video acceleration
    libva-utils
    mesa-demos

    # PDF viewer
    zathura

    # CLI tools
    pkgs.unstable.claude-code
    p7zip

    # Browsers
    zen-browser

    # Notes
    obsidian
  ];

  # Wayland environment
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
