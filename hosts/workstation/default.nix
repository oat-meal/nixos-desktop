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

    # Desktop environment
    ../common/optional/desktop/niri
    ../common/optional/desktop/audio.nix
    ../common/optional/desktop/fonts.nix
    ../common/optional/desktop/apps.nix

    # Gaming
    ../common/optional/gaming

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
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Power
    ../common/optional/power/performance.nix

    # Security
    ../common/optional/security/sudo.nix

    # Storage
    ../common/optional/storage/zfs-maintenance.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "workstation-nixos";
  system.stateVersion = "25.05";

  ################################
  ## Kernel
  ################################
  boot.kernelPackages = pkgs.linuxPackages_latest;
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
  ];

  boot.kernelModules = [
    "ath12k_pci"
  ];

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
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
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
