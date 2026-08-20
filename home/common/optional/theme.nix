{ config, pkgs, lib, ... }:

{
  #############################
  ## GTK / Icons / Cursor
  #############################

  home.pointerCursor = {
    name = "catppuccin-macchiato-dark-cursors";
    package = pkgs.catppuccin-cursors;
    size = 16;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    gtk2.force = true;

    theme = {
      name = "catppuccin-macchiato-mauve-standard+default";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "macchiato";
      };
    };

    # 26.05 changed this default from config.gtk.theme to null, which would leave GTK4
    # apps unthemed while GTK2/3 stayed Catppuccin. Pinned to the previous behaviour.
    gtk4.theme = config.gtk.theme;

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders;
    };
  };
}
