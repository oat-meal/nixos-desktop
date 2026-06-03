# Desktop applications
# File managers, GUI tools, and common desktop packages

{ pkgs, ... }:

{
  # Virtual filesystem for file managers
  services.gvfs.enable = true;

  environment.systemPackages = with pkgs; [
    # File management
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.tumbler
    xarchiver
    trash-cli

    # Terminal
    alacritty

    # Wayland tools
    wayland
    xwayland

    # Cursors
    catppuccin-cursors
    bibata-cursors

    # X11 compatibility
    xorg.libXcursor
    xorg.libX11
    xorg.libXrandr
    xorg.libXext
    xorg.libxcb

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
