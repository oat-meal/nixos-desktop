# MangoWM — dwl-based Wayland compositor (NixOS / system module).
#
# Imported by the workstation only. Provides the mango compositor + a greetd
# session entry that sits ALONGSIDE the niri session (see ../niri/default.nix),
# so niri remains a one-keystroke fallback at the tuigreet session picker.
#
# All the shared desktop infrastructure — greetd itself, xdg portals, polkit,
# gnome-keyring, wl-clipboard, grim/slurp, wallpaper tools — is defined in the
# niri system module and reused as-is; this file adds only what is mango-specific.

{ pkgs, inputs, ... }:

{
  imports = [ inputs.mango.nixosModules.mango ];

  programs.mango.enable = true;

  # Session entry for greetd (tuigreet reads /etc/greetd/sessions). uwsm/dbus env
  # is handled by the Home Manager module's systemd integration (systemd.enable).
  environment.etc."greetd/sessions/mango.desktop".text = ''
    [Desktop Entry]
    Name=Mango
    Comment=dwl-based Wayland compositor
    Exec=mango
    Type=Application
  '';
}
