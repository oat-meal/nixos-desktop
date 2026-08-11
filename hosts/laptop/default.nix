# Framework 13 laptop configuration
# AMD Ryzen, MangoWM compositor, power management optimized

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

    # Gaming
    ../common/optional/gaming

    # Hardware
    ../common/optional/hardware/amd.nix
    ../common/optional/hardware/bluetooth.nix
    ../common/optional/hardware/framework.nix

    # Networking
    ../common/optional/networking/firewall.nix
    ../common/optional/networking/nordvpn.nix
    ../common/optional/networking/sops.nix
    ../common/optional/networking/ssh.nix
    ../common/optional/networking/syncthing.nix
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Power
    ../common/optional/power/portable.nix
    ../common/optional/power/hibernate.nix

    # Security
    ../common/optional/security/sudo.nix

    # Storage
    ../common/optional/storage/zfs-maintenance.nix
    ../common/optional/monitoring/post-rebuild-verify.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "laptop-nixos";
  system.stateVersion = "25.05";

  ################################
  ## Kernel
  ################################
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
  boot.consoleLogLevel = 1;

  # Laptop-specific kernel params
  boot.kernelParams = lib.mkAfter [
    "amd_pstate.shared_mem=1"
    "amdgpu.abmlevel=0"  # Disable adaptive backlight to prevent GPU idle lockups
  ];

  ################################
  ## Kernel module autoload fix (2026-08-10)
  ################################
  # On this host (linux_6_12 + systemd-initrd) the NixOS activation step that
  # points /proc/sys/kernel/modprobe at the real kmod modprobe does not take
  # effect at boot, leaving it at the compiled-in default "/sbin/modprobe"
  # (which does not exist on NixOS). That silently breaks on-demand kernel
  # module autoloading, cascading into: /boot (vfat) failing to mount, the
  # firewall failing ("nft: Protocol not supported"), and a crippled network
  # stack. `nixos-rebuild switch` runs activation as full root and fixes it for
  # the running session, but it recurs on every reboot. Two independent, boot-
  # ordered safeguards (systemd-sysctl and systemd-modules-load both hold
  # CAP_SYS_MODULE and run before firewall.service / boot.mount):

  # 1. Set the autoload helper path via systemd-sysctl (covers ALL on-demand
  #    module autoloading — firewall nftables modules, hotplugged hardware, …).
  boot.kernel.sysctl."kernel.modprobe" = "${pkgs.kmod}/bin/modprobe";

  # 2. Guarantee the ESP's filesystem modules are present regardless of the
  #    autoload path, so /boot always mounts (vfat pulls fat as a dependency).
  #    af_packet (CONFIG_PACKET=m) is likewise forced: without it socket(AF_PACKET)
  #    returns EAFNOSUPPORT, breaking NM's DHCP client and wpa_supplicant (WiFi) —
  #    systemd-modules-load loads it via libkmod, independent of the modprobe path.
  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" "af_packet" ];

  # 3. Actually run (1) and (2) against the real root.
  #    Root cause (diagnosed 2026-08-10, boot c99796eb): with systemd-initrd,
  #    systemd-sysctl.service and systemd-modules-load.service run *inside the
  #    initrd*, are restarted there by the daemon-reload that initrd-parse-etc
  #    triggers, and — being Type=oneshot + RemainAfterExit=yes — their
  #    "active (exited)" state is serialized across switch_root. systemd
  #    therefore never re-runs them against the real /etc, so /etc/sysctl.d and
  #    /etc/modules-load.d are silently never applied: every value in
  #    60-nixos.conf stayed at its kernel default (verified: vm.swappiness 60
  #    not 1, kernel.pid_max 32768 not 4194304, rp_filter 0 not 2, and
  #    kernel.modprobe still /sbin/modprobe), and af_packet/vfat were never
  #    inserted. `nixos-rebuild switch` masks it by restarting both units as
  #    full root, which is why it only ever recurred on reboot.
  #    Re-invoking the two generators after switch_root applies both, and does
  #    so before the consumers that were failing (boot.mount, firewall.service,
  #    NetworkManager/wpa_supplicant).
  systemd.services.reapply-kernel-config = {
    description = "Re-apply /etc/sysctl.d and /etc/modules-load.d after switch-root";
    wantedBy = [ "sysinit.target" ];
    before = [
      "boot.mount"
      "firewall.service"
      "network-pre.target"
      "NetworkManager.service"
      "wpa_supplicant.service"
    ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${config.systemd.package}/lib/systemd/systemd-modules-load"
        "${config.systemd.package}/lib/systemd/systemd-sysctl"
      ];
    };
  };

  ################################
  ## GameMode override (laptop)
  ################################
  # 8-core laptop CPU: reserve 4 cores for system, pin games to 4
  programs.gamemode.settings.cpu.core_count = lib.mkForce 4;
  programs.gamemode.settings.gpu.gpu_device = lib.mkForce 1;  # GPU is card1 on this laptop

  ################################
  ## WiFi power saving (laptop)
  ################################
  networking.networkmanager.wifi.powersave = true;

  ################################
  ## User groups
  ################################
  users.users.oat.extraGroups = lib.mkAfter [ "audio" "video" "input" "gamemode" ];

  ################################
  ## Moonlight — game-stream client for the workstation's Sunshine host (wg0)
  ################################
  # For remote playtest: connect to workstation-nixos (10.100.0.1).
  environment.systemPackages = [ pkgs.moonlight-qt ];
}
