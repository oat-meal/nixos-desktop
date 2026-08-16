# Workstation configuration
# AMD Ryzen 9950X, dedicated GPU, gaming-optimized

{ config, pkgs, lib, ... }:

{
  imports = [
    # Security
    ../common/optional/security/luks.nix
    ../common/optional/security/hardening.nix

    ./hardware-configuration.nix

    # Core (required)
    ../common/core

    # Desktop environment (MangoWM + Noctalia; base = shared greetd/portals/polkit)
    ../common/optional/desktop/base.nix
    ../common/optional/desktop/mango
    ../common/optional/desktop/audio.nix
    ../common/optional/desktop/fonts.nix
    ../common/optional/desktop/apps.nix
    ../common/optional/desktop/sunshine.nix  # game-stream host → Moonlight on laptop (wg0)

    # Gaming
    ../common/optional/gaming
    ../common/optional/ai/eliteintel.nix
    ../common/optional/ai/comfyui-render.nix  # image-gen render node (ComfyUI on the 9070 XT)

    # Hardware
    ../common/optional/hardware/amd.nix
    ../common/optional/hardware/kernel-module-autoload.nix
    ../common/optional/hardware/bluetooth.nix
    ../common/optional/hardware/printing.nix

    # Networking
    ../common/optional/networking/firewall.nix
    ../common/optional/networking/nordvpn.nix
    ../common/optional/networking/sops.nix
    ../common/optional/networking/ssh.nix
    ../common/optional/networking/syncthing.nix
    ../common/optional/networking/tailscale.nix
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Power
    ../common/optional/power/performance.nix

    # Security
    ../common/optional/security/sudo.nix

    # Storage
    ../common/optional/storage/zfs-maintenance.nix

    # Monitoring — PARKED (2026-08-16). Not blocked, deliberately deferred until the
    # lab's observability tooling/strategy is re-evaluated as a whole.
    #
    # History: disabled 2026-08-03 while bisecting the WiFi regression (these were the
    # only functional additions between working gen 50 and failing gen 51, ath12k
    # "wpa_supplicant couldn't grab interface"). That investigation CLOSED — the cause
    # was confirmed as stack-smoke-test's Persistent timer + wants=network-online.target
    # pulling the target into the boot transaction (commit 183f279, postmortem item 8).
    #
    # Both modules are now safe to re-enable on the technical merits: the anti-pattern
    # was removed from stack-smoke-test (2026-08-16) and post-rebuild-verify never had
    # it. They stay off by choice, not by risk. When observability is revisited, decide
    # whether these ad-hoc units are still the right shape at all — note both alert to
    # the lab ntfy hub on the server, so neither can report a server that is itself down
    # (postmortem action item #3, still open).
    #
    # See docs/audit/workstation.md and docs/audit/postmortem-2026-08-wcn7850-wifi.md.
    # ../common/optional/monitoring/post-rebuild-verify.nix
    # ../common/optional/monitoring/stack-smoke-test.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "workstation-nixos";
  system.stateVersion = "25.05";

  ################################
  ## Kernel
  ################################
  # Pinned to the 7.0 line (was linuxPackages_latest) as a conservative default for
  # the bleeding-edge WCN785x/ath12k_wifi7 card. Both 7.0.10 and 7.0.14 are KNOWN-GOOD.
  #
  # NOTE (2026-08-03): the earlier "7.0.14 breaks WiFi (-517)" belief was WRONG — it
  # was confounded by the stack-smoke-test monitoring's boot-ordering grab race (see
  # docs/audit/workstation.md). With that monitoring removed, 7.0.14 boots WiFi
  # cleanly. The pin now just avoids surprise MAJOR kernel jumps; patch bumps within
  # 7.0.x are fine. Safe to bump this attr deliberately (and reboot-test WiFi) when wanted.
  boot.kernelPackages = pkgs.linuxPackages_7_0;
  boot.consoleLogLevel = 1;

  # Desktop-specific kernel params (gaming optimized)
  boot.kernelParams = lib.mkAfter [
    "transparent_hugepage=madvise"
    "hugepagesz=2M"
    "default_hugepagesz=2M"
    "preempt=full"
    "snd_hda_intel.power_save=0"
    "usbhid.mousepoll=1"
    "pci=pcie_bus_perf"
    "usbcore.autosuspend=-1"
    "pcie_aspm=off"
    # Cap ZFS ARC at 16 GB. Default (uncapped ≈ 50% RAM) held ~34 GB of the 60 GB
    # and starved games — a Steam update's write/decompress burst pushed RAM into
    # swap and stalled the desktop. 16 GB cache leaves ~44 GB for games.
    "zfs.zfs_arc_max=17179869184"
    # Don't penalize bus-locking threads. The kernel was rate-limiting Steam's job
    # threads (CJobMgr bus_lock traps) during the update, causing brief hitches.
    "split_lock_detect=off"
  ];

  boot.kernelModules = [
    "ath12k_pci"
  ];

  ################################
  ## Anti-cheat (EAC) override
  ################################
  # EasyAntiCheat (Elden Ring Nightreign, etc.) must ptrace the game process
  # it launches; hardening.nix sets scope 2 (admin-only), which makes EAC fail
  # module mapping with "Unexpected error (#1)". Scope 1 = descendants-only,
  # which is enough for EAC and matches hardening.nix's documented intent.
  # Workstation-only override — server and laptop keep scope 2.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkForce 1;

  ################################
  ## GameMode override (16-core CPU)
  ################################
  # Ryzen 9950X: reserve 4 cores for system, pin games to 12
  programs.gamemode.settings.cpu.core_count = lib.mkForce 12;

  ################################
  ## User groups (extended for desktop peripherals)
  ################################
  users.groups.plugdev = {};
  users.users.oat.extraGroups = lib.mkAfter [ "audio" "video" "dialout" "uucp" "plugdev" "input" ];

  ################################
  ## USB device support (gaming peripherals, VR)
  ################################
  hardware.usb-modeswitch.enable = true;

  services.udev.extraRules = ''
    # ASUS ROG devices
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1aa2", TAG+="uaccess"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", TAG+="uaccess"

    # Gaming peripherals
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0664", GROUP="input"

    # Xbox controllers
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02fd", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b12", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b13", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b20", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b21", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b22", MODE="0664", GROUP="input", TAG+="uaccess"

    # PS5 DualSense
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="js*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="event*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0664", GROUP="input", TAG+="uaccess"

    # PS4 DualShock
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0664", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0664", GROUP="input", TAG+="uaccess"

    # Meta Quest VR
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2833", ATTRS{idProduct}=="0186", MODE="0664", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2833", ATTRS{idProduct}=="0051", MODE="0664", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2833", ATTRS{idProduct}=="0183", MODE="0664", GROUP="plugdev", TAG+="uaccess"

    # USB audio
    SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="01", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", TAG+="uaccess"

    # WiFi power management (USB/PCI power rules removed — usbcore.autosuspend=-1 handles globally)
    SUBSYSTEM=="net", ACTION=="add", KERNEL=="wl*", RUN+="/bin/sh -c 'echo on > /sys/class/net/%k/device/power/control'"

    # NVMe scheduler
    ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"

    # Hide ZFS member devices from udisks2/Thunar sidebar
    ENV{ID_FS_TYPE}=="zfs_member", ENV{UDISKS_IGNORE}="1"
  '';

  ################################
  ## WiFi shutdown cleanup (desktop-specific driver issue)
  ################################
  systemd.services.wifi-shutdown-cleanup = {
    description = "Clean ath12k WiFi driver before shutdown";
    wantedBy = [ "shutdown.target" ];
    before = [ "shutdown.target" "reboot.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = pkgs.writeShellScript "wifi-shutdown-cleanup" ''
        echo "Disabling WiFi interface wlp16s0 for clean shutdown"
        ${pkgs.iproute2}/bin/ip link set wlp16s0 down 2>/dev/null || true
        echo "on" > /sys/class/net/wlp16s0/power/control 2>/dev/null || true
        sleep 2
      '';
      TimeoutStopSec = "15s";
    };
  };

  ################################
  ## NFS mount — server storage
  ################################
  fileSystems."/mnt/server" = {
    device = "10.100.0.2:/storage";
    fsType = "nfs";
    # hard mount (implicit default) for data integrity; fast-fail so touching
    # /mnt/server while the server is offline errors in ~10s instead of hanging
    # Thunar for minutes. Re-mounts automatically on next access when server is up.
    options = [
      "x-systemd.automount"
      "noauto"
      "_netdev"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10s"  # systemd cancels the mount job after 10s
      "retry=0"                       # mount.nfs: fail now, no 2-min fg retry loop
      "timeo=50"                      # 5s per-RPC timeout (deciseconds)
      "retrans=2"                     # 2 retries before "server not responding"
    ];
  };

  ################################
  ## Flatpak support
  ################################
  services.flatpak.enable = true;

  ################################
  ## nix-ld for unpatched binaries (Fightcade, etc.)
  ################################
  # nix-ld for unpatched binaries (Fightcade, AppImages)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Electron/Chromium runtime (Fightcade, Discord AppImage)
      nss nspr atk at-spi2-atk at-spi2-core cups libdrm
      gtk3 pango cairo gdk-pixbuf glib dbus expat libxkbcommon
      # Graphics
      alsa-lib mesa libGL libGLU
      # System
      systemd udev zlib stdenv.cc.cc.lib
      # X11 (required by most unpatched Linux binaries)
      xorg.libX11 xorg.libXcomposite xorg.libXdamage xorg.libXext
      xorg.libXfixes xorg.libXrandr xorg.libxcb xorg.libXcursor
      xorg.libXi xorg.libXrender xorg.libXtst xorg.libXScrnSaver
      xorg.libxshmfence
      # Audio/desktop integration
      libpulseaudio libnotify libappindicator-gtk3 libsecret ffmpeg
    ];
  };
}
