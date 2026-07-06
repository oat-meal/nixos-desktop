# MangoWM — Home Manager config. Imported by every desktop host.
#
# Design:
#   - Default layout is `scroller` on every tag, to mimic niri's scrollable feel.
#   - SUPER is the primary modifier (matches the old niri Mod).
#   - Noctalia is the full shell: bar, notifications, OSDs, launcher, clipboard,
#     lock, session menu, screenshots, brightness/volume — driven via `noctalia
#     msg` IPC (full store path, so binds don't depend on the session PATH).
#
# Approximations vs the old niri setup (mango's tag/dwl model differs):
#   - niri column-stacking (consume/expel) has no direct analog → omitted.
#   - column width -/+10% → scroller set_proportion presets (Mod+R cycles).

{ pkgs, inputs, ... }:

let
  noctalia = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  nc = "${noctalia}/bin/noctalia";

  # Screen recording toggle: first press picks a region (slurp) and starts
  # wl-screenrec (VAAPI hardware encode); second press stops it. Files land in
  # ~/Videos. Notifications render via Noctalia's notification daemon.
  screenrec-toggle = pkgs.writeShellScriptBin "screenrec-toggle" ''
    dir="$HOME/Videos"
    if ${pkgs.procps}/bin/pkill -INT -x wl-screenrec; then
      ${pkgs.libnotify}/bin/notify-send "Screen recording" "Stopped — saved in $dir"
      exit 0
    fi
    mkdir -p "$dir"
    region="$(${pkgs.slurp}/bin/slurp)" || exit 0
    ${pkgs.libnotify}/bin/notify-send "Screen recording" "Recording region to $dir"
    exec ${pkgs.wl-screenrec}/bin/wl-screenrec -g "$region" -f "$dir/rec-$(date +%Y%m%d-%H%M%S).mp4"
  '';
in
{
  imports = [ inputs.mango.hmModules.mango ];

  # Also on PATH for manual use (e.g. full-screen: wl-screenrec -f out.mp4)
  home.packages = [ screenrec-toggle ];

  wayland.windowManager.mango = {
    enable = true;

    # Import graphical-session env into systemd/D-Bus (portals, etc.).
    systemd.enable = true;

    # Startup: wallpaper (video on AC / static on battery) + the Noctalia shell.
    # Noctalia provides the polkit agent, network/bluetooth controls and clipboard,
    # so lxqt-policykit / nm-applet / cliphist are no longer launched here.
    autostart_sh = ''
      "$HOME/.local/bin/wallpaper-power-switch" &
      ${nc} -d &
    '';

    # Full config in mango's native format. See https://mangowm.github.io/docs
    extraConfig = ''
      # ---------------- Appearance ----------------
      gappih=8
      gappiv=8
      gappoh=8
      gappov=8
      borderpx=2
      rootcolor=0x24273aff
      bordercolor=0x494d64ff
      focuscolor=0xc6a0f6ff
      border_radius=6

      # ---------------- Animations ----------------
      animations=1
      animation_type_open=slide
      animation_type_close=slide

      # ---------------- Keyboard ----------------
      xkb_rules_layout=us
      repeat_rate=50
      repeat_delay=300

      # ---------------- Pointer / touchpad ----------------
      sloppyfocus=1
      warpcursor=0
      tap_to_click=1
      trackpad_natural_scrolling=1
      disable_while_typing=1

      # ---------------- Default layout per tag: scroller (niri-like) ----------------
      tagrule=id:1,layout_name:scroller
      tagrule=id:2,layout_name:scroller
      tagrule=id:3,layout_name:scroller
      tagrule=id:4,layout_name:scroller
      tagrule=id:5,layout_name:scroller
      tagrule=id:6,layout_name:scroller
      tagrule=id:7,layout_name:scroller
      tagrule=id:8,layout_name:scroller
      tagrule=id:9,layout_name:scroller

      # ---------------- Launchers ----------------
      bind=SUPER,d,spawn,${nc} msg panel-toggle launcher
      bind=SUPER,Return,spawn,alacritty
      bind=SUPER,e,spawn,alacritty -e yazi
      bind=SUPER,b,spawn,librewolf

      # ---------------- Window management ----------------
      bind=SUPER,q,killclient,
      bind=SUPER,f,togglemaximizescreen,
      bind=SUPER+SHIFT,f,togglefullscreen,
      bind=SUPER,space,togglefloating,
      bind=SUPER,t,setlayout,deck

      # ---------------- Focus (vim + arrows) ----------------
      bind=SUPER,h,focusdir,left
      bind=SUPER,j,focusdir,down
      bind=SUPER,k,focusdir,up
      bind=SUPER,l,focusdir,right
      bind=SUPER,Left,focusdir,left
      bind=SUPER,Down,focusdir,down
      bind=SUPER,Up,focusdir,up
      bind=SUPER,Right,focusdir,right

      # ---------------- Move window (swap) ----------------
      bind=SUPER+SHIFT,h,exchange_client,left
      bind=SUPER+SHIFT,j,exchange_client,down
      bind=SUPER+SHIFT,k,exchange_client,up
      bind=SUPER+SHIFT,l,exchange_client,right
      bind=SUPER+SHIFT,Left,exchange_client,left
      bind=SUPER+SHIFT,Down,exchange_client,down
      bind=SUPER+SHIFT,Up,exchange_client,up
      bind=SUPER+SHIFT,Right,exchange_client,right

      # ---------------- Tags (niri "workspaces") ----------------
      bind=SUPER,1,view,1,0
      bind=SUPER,2,view,2,0
      bind=SUPER,3,view,3,0
      bind=SUPER,4,view,4,0
      bind=SUPER,5,view,5,0
      bind=SUPER,6,view,6,0
      bind=SUPER,7,view,7,0
      bind=SUPER,8,view,8,0
      bind=SUPER,9,view,9,0
      bind=SUPER+SHIFT,1,tag,1,0
      bind=SUPER+SHIFT,2,tag,2,0
      bind=SUPER+SHIFT,3,tag,3,0
      bind=SUPER+SHIFT,4,tag,4,0
      bind=SUPER+SHIFT,5,tag,5,0
      bind=SUPER+SHIFT,6,tag,6,0
      bind=SUPER+SHIFT,7,tag,7,0
      bind=SUPER+SHIFT,8,tag,8,0
      bind=SUPER+SHIFT,9,tag,9,0

      # ---------------- Tag navigation ----------------
      bind=SUPER,Tab,focusstack,next
      bind=SUPER,Page_Down,viewtoright,0
      bind=SUPER,Page_Up,viewtoleft,0
      bind=SUPER+SHIFT,Page_Down,tagtoright,0
      bind=SUPER+SHIFT,Page_Up,tagtoleft,0

      # ---------------- Scroller proportion (niri preset widths) ----------------
      bind=SUPER,r,switch_proportion_preset,
      bind=SUPER,minus,set_proportion,0.5
      bind=SUPER,equal,set_proportion,1.0

      # ---------------- Overview / layout ----------------
      bind=SUPER,o,toggleoverview,
      bind=SUPER+SHIFT,space,switch_layout,

      # ---------------- Wheel: tag navigation (niri Mod+scroll) ----------------
      axisbind=SUPER,DOWN,viewtoright_have_client
      axisbind=SUPER,UP,viewtoleft_have_client

      # ---------------- Shell: Noctalia panels ----------------
      bind=SUPER,v,spawn,${nc} msg panel-toggle clipboard
      bind=SUPER,c,spawn,${nc} msg panel-toggle control-center

      # ---------------- Screenshots (Noctalia) ----------------
      bind=none,Print,spawn,${nc} msg screenshot-fullscreen
      bind=SUPER+SHIFT,s,spawn,${nc} msg screenshot-region

      # ---------------- Screen recording (region toggle: start / stop) ----------------
      bind=SUPER+CTRL,s,spawn,${screenrec-toggle}/bin/screenrec-toggle

      # ---------------- Caffeine (idle inhibit toggle) ----------------
      bind=SUPER+SHIFT,c,spawn,${nc} msg caffeine-toggle

      # ---------------- Lock / session / power ----------------
      bind=SUPER,Escape,spawn,${nc} msg session lock
      bind=SUPER+SHIFT,e,quit,
      bind=SUPER+SHIFT,p,spawn,${nc} msg panel-toggle session

      # ---------------- Reload mango config ----------------
      bind=SUPER+SHIFT,r,reload_config

      # ---------------- Volume / mic / media (Noctalia OSD; work while locked) ----------------
      bindl=none,XF86AudioRaiseVolume,spawn,${nc} msg volume-up
      bindl=none,XF86AudioLowerVolume,spawn,${nc} msg volume-down
      bindl=none,XF86AudioMute,spawn,${nc} msg volume-mute
      bindl=none,XF86AudioMicMute,spawn,${nc} msg mic-mute
      bind=none,XF86AudioPlay,spawn,${nc} msg media toggle
      bind=none,XF86AudioNext,spawn,${nc} msg media next
      bind=none,XF86AudioPrev,spawn,${nc} msg media previous

      # ---------------- Brightness (Noctalia OSD) ----------------
      bindl=none,XF86MonBrightnessUp,spawn,${nc} msg brightness-up
      bindl=none,XF86MonBrightnessDown,spawn,${nc} msg brightness-down

      # ---------------- Window rules (float dialogs / launchers / PiP) ----------------
      windowrule=isfloating:1,appid:steam
      windowrule=isfloating:1,appid:lutris
      windowrule=isfloating:1,appid:heroic
      windowrule=isfloating:1,appid:pavucontrol
      windowrule=isfloating:1,appid:nm-connection-editor
      windowrule=isfloating:1,appid:blueman-manager
      windowrule=isfloating:1,title:Picture-in-Picture
    '';
  };
}
