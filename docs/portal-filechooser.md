# Wayland: file/folder pickers do nothing (xdg-desktop-portal FileChooser)

## Symptom
On a minimal Wayland compositor (e.g. MangoWM), GTK/Electron apps' file dialogs silently
fail — e.g. Obsidian "Open folder as vault" does nothing, browser upload/download pickers
never appear. No error to the user.

## Cause
`xdg-desktop-portal` routed the `FileChooser` interface to the **GNOME** backend, whose
implementation **delegates to Nautilus** — which isn't installed. The call fails silently:

```
xdg-desktop-portal-gnome: Delegated FileChooser call failed:
The name org.gnome.Nautilus was not provided by any .service files
```

Compounding it: the portal config referenced `gtk` for some interfaces, but
`xdg-desktop-portal-gtk` was never in `extraPortals`, so there was no GTK backend to fall
back to.

## Fix
In the shared desktop base (`hosts/common/optional/desktop/base.nix`), add the GTK portal
and route `FileChooser` to it (GTK's portal has a built-in chooser; no Nautilus needed):

```nix
xdg.portal = {
  enable = true;
  extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
  config.common = {
    default = [ "gnome" "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
};
```

Deploy, then **restart the user portal services** (a system rebuild doesn't restart user
services) or re-login:

```
systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gnome.service
```

Electron apps (Obsidian, etc.) bind the portal at launch — **fully quit and relaunch** them.

## Verify
```
# gtk backend present:
ls /run/current-system/sw/share/xdg-desktop-portal/portals/ | grep gtk   # -> gtk.portal
# FileChooser routed to gtk:
grep -r FileChooser /run/current-system/sw/share/xdg-desktop-portal/*portals.conf
# -> org.freedesktop.impl.portal.FileChooser=gtk
```

Fixes all file dialogs, not just Obsidian. Commit `9a7bb53` (2026-06-07).
Alternative fix would be installing Nautilus, but the GTK portal is lighter and the standard
choice for non-GNOME compositors.
