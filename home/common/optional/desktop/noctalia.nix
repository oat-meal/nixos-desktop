# Noctalia v5 — native Wayland desktop shell (bar, launcher, control center,
# notifications, OSDs, clipboard, lock screen, session menu, tray, ...).
#
# The shell for MangoWM on every desktop host. Launched from mango's autostart
# (`noctalia -d`, see ../desktop/mango/home.nix), so no systemd user service is
# needed here. Keybinds drive it via `noctalia msg` IPC.

{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;

    # Started by mango's autostart, not a user service.
    systemd.enable = false;

    # settings accepts Nix attrs (serialized to Noctalia's TOML config).
    # Starting point only — flavor/details are hot-reloadable in the GUI.
    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
    };
  };
}
