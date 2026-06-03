{ config, pkgs, lib, ... }:

{
  ################################
  ## Fuzzel - Application Launcher
  ## Catppuccin Macchiato themed
  ################################

  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
        terminal = "${pkgs.alacritty}/bin/alacritty -e";
        layer = "overlay";
        prompt = "❯ ";

        # Dimensions
        width = 50;
        lines = 12;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 8;

        # Behavior
        show-actions = false;
      };

      colors = {
        # Catppuccin Macchiato
        background = "24273add";        # base with alpha
        text = "cad3f5ff";              # text
        match = "c6a0f6ff";             # mauve (highlight matches)
        selection = "363a4fff";         # surface0
        selection-text = "cad3f5ff";    # text
        selection-match = "c6a0f6ff";   # mauve
        border = "c6a0f6ff";            # mauve
      };

      border = {
        width = 2;
        radius = 12;
      };

      dmenu = {
        # dmenu mode styling (for scripts like cliphist)
        mode = "text";
      };
    };
  };
}
