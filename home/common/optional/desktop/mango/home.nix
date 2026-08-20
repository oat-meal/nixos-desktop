# MangoWM — Home Manager config. Imported by every desktop host.
#
# Design:
#   - Default layout is `scroller` on every tag, for a horizontally-scrollable feel.
#   - SUPER is the primary modifier.
#   - Noctalia is the full shell: bar, notifications, OSDs, launcher, clipboard,
#     lock, session menu, screenshots, brightness/volume — driven via `noctalia
#     msg` IPC (full store path, so binds don't depend on the session PATH).
#
# Notes on mango's tag/dwl model:
#   - column-stacking (consume/expel) has no direct analog in dwl → omitted.
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

  # Lab notification bridge: subscribe to the self-hosted ntfy `lab-alerts` topic
  # (Claude Code hooks + fleet-sentinel + backup checks publish there) and render
  # each message via notify-send → Noctalia's notification center. ntfy sets
  # $message/$title/$priority in the env of the exec'd command.
  ntfy-notify = pkgs.writeShellScript "ntfy-to-noctalia" ''
    urg=normal
    case "''${priority:-3}" in 4|5|max|urgent|high) urg=critical ;; 1|2|min|low) urg=low ;; esac
    exec ${pkgs.libnotify}/bin/notify-send -a "Lab" -u "$urg" -i dialog-information "''${title:-Lab notification}" "''${message:-}"
  '';
  ntfy-bridge = pkgs.writeShellScript "lab-ntfy-bridge" ''
    while :; do
      ${pkgs.ntfy-sh}/bin/ntfy subscribe http://10.100.0.2:2586/lab-alerts ${ntfy-notify} || true
      sleep 5   # reconnect after a dropped subscription (network blip / server restart)
    done
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
      ${ntfy-bridge} &
    '';

    # Full config in mango's native format. See https://mangowm.github.io/docs
    extraConfig = ''
      # ---------------- Displays (HiDPI scaling) ----------------
      # Framework 13 internal panel is 2880x1920 on a 13.5" screen (~250 PPI);
      # at scale 1.0 everything renders tiny. Scale 2.0 → logical 1440x960 — a small
      # workspace, but 1.5 (logical 1920x1280) was still too small to read comfortably
      # at this PPI (raised 2026-08-16). 2.0 is also an INTEGER scale, so it avoids the
      # fractional-scaling blur that 1.5 inflicts on Xwayland clients.
      # Anchored to ^eDP-1$ so it's a no-op on hosts without that output.
      monitorrule=name:^eDP-1$,scale:2.0

      # Workstation LG UltraGear is 3840x2160 on a ~48" panel (~92 PPI); scale 1.25 →
      # logical 3072x1728. Was 2.0 (logical 1920x1080) until 2026-08-16 — that was
      # chosen to give the Sunshine 1080p stream a 1:1 capture, but it traded away most
      # of the desktop's real estate on a panel whose PPI does not need that much
      # scaling. Streaming now downscales instead; if the softer stream ever becomes the
      # bigger annoyance, fix it with a Sunshine-specific mode rather than by shaping the
      # whole desktop around the capture. Anchored to ^DP-1$.
      monitorrule=name:^DP-1$,scale:1.25

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
      # Renamed upstream 2026-07/08: the bare disable_while_typing is now only
      # valid inside an inputrule block; the global option carries the
      # trackpad_ prefix. Same semantics, same default source.
      trackpad_disable_while_typing=1

      # ---------------- Default layout per tag: scroller ----------------
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

      # ---------------- Tags (workspaces) ----------------
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

      # ---------------- Scroller proportion (preset widths) ----------------
      bind=SUPER,r,switch_proportion_preset,
      bind=SUPER,minus,set_proportion,0.5
      bind=SUPER,equal,set_proportion,1.0

      # ---------------- Overview / layout ----------------
      bind=SUPER,o,toggleoverview,
      bind=SUPER+SHIFT,space,switch_layout,

      # ---------------- Wheel: tag navigation (Mod+scroll) ----------------
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
      # Steam: the main window tiles like any other client. Only its transient
      # popups float — a blanket appid:steam float also caught the main window,
      # which then sat on top of the layout instead of joining it.
      # Startup window (shows sign-in / update progress before the main window
      # exists, ~4.8s-6.5s in). Distinct title from the main window's "Steam",
      # so floating it does not disturb the tiled layout on launch.
      windowrule=isfloating:1,appid:steam,title:Sign in to Steam
      windowrule=isfloating:1,appid:steam,title:Friends List
      windowrule=isfloating:1,appid:steam,title:Steam Settings
      windowrule=isfloating:1,appid:steam,title:Special Offers
      windowrule=isfloating:1,appid:lutris
      windowrule=isfloating:1,appid:heroic
      windowrule=isfloating:1,appid:pavucontrol
      windowrule=isfloating:1,appid:nm-connection-editor
      windowrule=isfloating:1,appid:blueman-manager
      windowrule=isfloating:1,title:Picture-in-Picture
    '';
  };
}
