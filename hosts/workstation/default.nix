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
    ../common/optional/monitoring/post-rebuild-verify.nix
    ../common/optional/monitoring/stack-smoke-test.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "workstation-nixos";
  system.stateVersion = "25.05";

  ################################
  ## Kernel
  ################################
  # Pinned to the 7.0 line (was linuxPackages_latest). The WCN785x Wi-Fi 7 card
  # relies on the bleeding-edge in-tree ath12k_wifi7 driver, so an implicit
  # kernel bump from a flake update can silently break WiFi. Pinning keeps the
  # kernel stable; bump this attr deliberately (and test WiFi) when wanted.
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
  ## WiFi warm-reboot auto-recovery (ath12k WCN785x firmware-init failure)
  ################################
  # The WCN785x (FastConnect 7800) intermittently fails QMI/firmware init after
  # a warm reboot: the PCIe function stops responding and the OS reports the
  # WiFi hardware as "missing" until a cold power cycle. This unit runs at boot
  # and, ONLY when no wlp16s0 interface came up, escalates recovery:
  #   1) unbind + rebind the PCI driver (firmware init failed, function on bus)
  #   2) reload the ath12k module stack
  #   3) PCI remove + bus rescan (function dropped off the bus)
  # It no-ops when WiFi is already present, so a healthy boot is left untouched.
  systemd.services.wifi-ath12k-recovery = {
    description = "Recover ath12k WiFi if the WCN785x failed to initialize";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wifi-ath12k-recovery" ''
        set -u
        IFACE=wlp16s0
        PCI=0000:10:00.0
        DRV=/sys/bus/pci/drivers/ath12k_wifi7_pci

        have_iface() { [ -e "/sys/class/net/$IFACE" ]; }

        if have_iface; then
          echo "ath12k: $IFACE present, no recovery needed"
          exit 0
        fi

        echo "ath12k: $IFACE missing — attempting recovery"

        # 1) unbind + rebind the PCI driver (function still on the bus)
        if [ -e "$DRV/$PCI" ]; then
          echo "ath12k: unbind/rebind $PCI"
          echo "$PCI" > "$DRV/unbind" 2>/dev/null || true
          sleep 1
          echo "$PCI" > "$DRV/bind" 2>/dev/null || true
          sleep 3
          have_iface && { echo "ath12k: recovered via rebind"; exit 0; }
        fi

        # 2) reload the module stack
        echo "ath12k: reloading module stack"
        ${pkgs.kmod}/bin/modprobe -r ath12k_wifi7 2>/dev/null || true
        ${pkgs.kmod}/bin/modprobe -r ath12k 2>/dev/null || true
        sleep 1
        ${pkgs.kmod}/bin/modprobe ath12k_wifi7 2>/dev/null || true
        sleep 3
        have_iface && { echo "ath12k: recovered via module reload"; exit 0; }

        # 3) re-enumerate the PCIe function
        echo "ath12k: PCI remove + rescan"
        [ -e "/sys/bus/pci/devices/$PCI/remove" ] && \
          echo 1 > "/sys/bus/pci/devices/$PCI/remove" 2>/dev/null || true
        sleep 1
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
        sleep 3
        have_iface && { echo "ath12k: recovered via PCI rescan"; exit 0; }

        echo "ath12k: recovery failed — a cold power cycle may be required"
        exit 0
      '';
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
