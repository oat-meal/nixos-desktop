{ config, pkgs, lib, ... }:

{
  ################################
  ## Yazi - Terminal File Manager
  ## Image preview + Mouse support + Catppuccin Macchiato
  ################################

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # Home Manager changed this default from "yy" to "y" in 26.05. Pinned to the
    # existing name so the migration does not silently change the shell command.
    shellWrapperName = "yy";

    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
        scrolloff = 5;

        # Mouse support
        mouse_events = [ "click" "scroll" ];
      };

      preview = {
        # Image preview settings
        image_filter = "lanczos3";
        image_quality = 90;
        max_width = 600;
        max_height = 900;
        cache_dir = "";

        # ueberzugpp settings
        ueberzug_scale = 1;
        ueberzug_offset = [ 0 0 0 0 ];
      };

      opener = {
        edit = [
          { run = ''nvim "$@"''; block = true; desc = "Edit with Neovim"; }
        ];
        open = [
          { run = ''xdg-open "$@"''; orphan = true; desc = "Open"; }
        ];
        reveal = [
          { run = ''xdg-open "$(dirname "$1")"''; orphan = true; desc = "Reveal in folder"; }
        ];
        play = [
          { run = ''mpv "$@"''; orphan = true; desc = "Play with mpv"; }
        ];
        extract = [
          { run = ''ouch decompress "$@"''; desc = "Extract archive"; }
        ];
      };

      open = {
        rules = [
          # Directories
          { name = "*/"; use = [ "edit" "open" "reveal" ]; }

          # Text files
          { mime = "text/*"; use = [ "edit" ]; }
          { mime = "application/json"; use = [ "edit" ]; }
          { mime = "application/x-yaml"; use = [ "edit" ]; }
          { mime = "application/toml"; use = [ "edit" ]; }

          # Media
          { mime = "image/*"; use = [ "open" "reveal" ]; }
          { mime = "video/*"; use = [ "play" "open" "reveal" ]; }
          { mime = "audio/*"; use = [ "play" "open" "reveal" ]; }

          # Documents
          { mime = "application/pdf"; use = [ "open" "reveal" ]; }

          # Archives
          { mime = "application/zip"; use = [ "extract" "open" "reveal" ]; }
          { mime = "application/gzip"; use = [ "extract" "open" "reveal" ]; }
          { mime = "application/x-tar"; use = [ "extract" "open" "reveal" ]; }
          { mime = "application/x-bzip2"; use = [ "extract" "open" "reveal" ]; }
          { mime = "application/x-7z-compressed"; use = [ "extract" "open" "reveal" ]; }
          { mime = "application/x-rar"; use = [ "extract" "open" "reveal" ]; }

          # Fallback
          { mime = "*"; use = [ "open" "reveal" ]; }
        ];
      };
    };

    # Custom keybindings
    keymap = {
      manager.prepend_keymap = [
        # Quick actions
        { on = [ "." ]; run = "hidden toggle"; desc = "Toggle hidden files"; }
        { on = [ "<C-n>" ]; run = "create"; desc = "Create file/directory"; }
        { on = [ "<C-r>" ]; run = "rename --cursor=before_ext"; desc = "Rename"; }
        { on = [ "D" ]; run = "remove --permanently"; desc = "Delete permanently"; }

        # Navigation shortcuts
        { on = [ "g" "h" ]; run = "cd ~"; desc = "Go to home"; }
        { on = [ "g" "d" ]; run = "cd ~/Downloads"; desc = "Go to Downloads"; }
        { on = [ "g" "c" ]; run = "cd ~/.config"; desc = "Go to config"; }
        { on = [ "g" "s" ]; run = "cd /storage"; desc = "Go to storage"; }
        { on = [ "g" "n" ]; run = "cd /etc/nixos"; desc = "Go to NixOS config"; }

        # Selection
        { on = [ "<Space>" ]; run = [ "select --state=none" "arrow 1" ]; desc = "Toggle select and move down"; }
        { on = [ "V" ]; run = "visual_mode"; desc = "Enter visual mode"; }
        { on = [ "<C-a>" ]; run = "select_all --state=true"; desc = "Select all"; }
        { on = [ "<C-d>" ]; run = "select_all --state=none"; desc = "Deselect all"; }

        # Shell
        { on = [ "!" ]; run = "shell --interactive"; desc = "Run shell command"; }
        { on = [ "$" ]; run = "shell --block --interactive"; desc = "Run shell command (blocking)"; }
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

        marker_copied = { fg = "#eed49f"; bg = "#eed49f"; };
        marker_cut = { fg = "#ed8796"; bg = "#ed8796"; };
        marker_marked = { fg = "#8bd5ca"; bg = "#8bd5ca"; };
        marker_selected = { fg = "#a6da95"; bg = "#a6da95"; };

        tab_active = { fg = "#24273a"; bg = "#c6a0f6"; };
        tab_inactive = { fg = "#cad3f5"; bg = "#363a4f"; };
        tab_width = 1;

        count_copied = { fg = "#24273a"; bg = "#eed49f"; };
        count_cut = { fg = "#24273a"; bg = "#ed8796"; };
        count_selected = { fg = "#24273a"; bg = "#a6da95"; };

        border = { fg = "#6e738d"; };
        syntect_theme = "";
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
        active = { fg = "#f5bde6"; bold = true; };
        inactive = {};
      };

      tasks = {
        border = { fg = "#8aadf4"; };
        title = {};
        hovered = { fg = "#f5bde6"; underline = true; };
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
        run = { fg = "#8bd5ca"; };
        desc = { fg = "#939ab7"; };
        hovered = { bg = "#494d64"; bold = true; };
        footer = { fg = "#363a4f"; bg = "#cad3f5"; };
      };

      filetype = {
        rules = [
          # Media
          { mime = "image/*"; fg = "#8bd5ca"; }
          { mime = "video/*"; fg = "#eed49f"; }
          { mime = "audio/*"; fg = "#eed49f"; }

          # Archives
          { mime = "application/zip"; fg = "#f5bde6"; }
          { mime = "application/gzip"; fg = "#f5bde6"; }
          { mime = "application/x-tar"; fg = "#f5bde6"; }
          { mime = "application/x-bzip2"; fg = "#f5bde6"; }
          { mime = "application/x-7z-compressed"; fg = "#f5bde6"; }
          { mime = "application/x-rar"; fg = "#f5bde6"; }

          # Documents
          { mime = "application/pdf"; fg = "#ed8796"; }
          { mime = "application/msword"; fg = "#8aadf4"; }
          { mime = "application/vnd.openxmlformats-officedocument.*"; fg = "#8aadf4"; }

          # Code
          { mime = "text/x-*"; fg = "#a6da95"; }
          { mime = "application/json"; fg = "#eed49f"; }
          { mime = "application/javascript"; fg = "#eed49f"; }

          # Fallback
          { name = "*"; fg = "#cad3f5"; }
          { name = "*/"; fg = "#8aadf4"; }
        ];
      };

      icon = {
        # Common directories
        rules = [
          { name = ".config/"; text = ""; }
          { name = ".git/"; text = ""; }
          { name = "Downloads/"; text = ""; }
          { name = "Documents/"; text = ""; }
          { name = "Pictures/"; text = ""; }
          { name = "Videos/"; text = ""; }
          { name = "Music/"; text = ""; }
          { name = "Desktop/"; text = ""; }
          { name = "node_modules/"; text = ""; }
        ];
      };
    };
  };

  ################################
  ## XDG Desktop Integration
  ################################
  # Set Thunar as default file manager for XDG (browser integration)
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = [ "thunar.desktop" ];
    };
  };

  ################################
  ## Dependencies for Yazi
  ################################
  home.packages = with pkgs; [
    # Image preview (works with Alacritty via overlay)
    ueberzugpp

    # Video thumbnails
    ffmpegthumbnailer

    # PDF preview
    poppler-utils

    # Archive handling
    ouch

    # Fast search
    fd
    ripgrep
    fzf

    # JSON preview formatting
    jq

    # File type detection
    file
  ];
}
