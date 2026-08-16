# Kernel module autoload fix for systemd-initrd hosts
#
# Import on any host with boot.initrd.systemd.enable = true (i.e. anything that
# imports security/luks.nix). First diagnosed on laptop-nixos 2026-08-10 (commits
# ba84971 / b7ecba3 / fdce496), then hit server-nixos identically on 2026-08-16.
#
# Symptom: after a reboot — but never after a `nixos-rebuild switch` — on-demand
# kernel module autoloading is dead. It cascades into /boot failing to mount
# ("unknown filesystem type 'vfat'"), firewall.service failing ("iptables: Failed
# to initialize nft: Protocol not supported"), NFS mount units failing, and
# container networking not coming up.
#
# Root cause: with systemd-initrd, systemd-sysctl.service and
# systemd-modules-load.service run *inside the initrd*, and — being Type=oneshot
# with RemainAfterExit=yes — their "active (exited)" state is serialized across
# switch_root. systemd therefore never re-runs them against the real /etc, so
# /etc/sysctl.d and /etc/modules-load.d are silently never applied. Notably
# kernel.modprobe stays at the compiled-in default /sbin/modprobe, which does not
# exist on NixOS, so every kernel-initiated autoload request fails silently.
# `nixos-rebuild switch` masks it by restarting both units as full root, which is
# why it only ever recurs on reboot.

{ config, pkgs, ... }:

{
  # 1. Point the autoload helper at the real kmod modprobe. Covers all on-demand
  #    autoloading: nftables modules, filesystem types, hotplugged hardware.
  boot.kernel.sysctl."kernel.modprobe" = "${pkgs.kmod}/bin/modprobe";

  # 2. Force-load the modules whose absence breaks boot regardless of the autoload
  #    path. systemd-modules-load inserts these via libkmod, independent of
  #    kernel.modprobe. vfat pulls fat as a dependency; without af_packet,
  #    socket(AF_PACKET) returns EAFNOSUPPORT and DHCP/wpa_supplicant break.
  boot.kernelModules = [ "vfat" "nls_cp437" "nls_iso8859_1" "af_packet" ];

  # 3. Actually apply (1) and (2) against the real root. Re-invoking the two
  #    generators after switch_root applies both, ordered before the consumers
  #    that were failing.
  systemd.services.reapply-kernel-config = {
    description = "Re-apply /etc/sysctl.d and /etc/modules-load.d after switch-root";
    wantedBy = [ "sysinit.target" ];
    before = [
      "boot.mount"
      "firewall.service"
      "network-pre.target"
      "NetworkManager.service"
      "wpa_supplicant.service"
      # NFS mounts race the fix otherwise: server-nixos booted 2026-08-16 with
      # "mount: /proc/fs/nfsd: unknown filesystem type 'nfsd'" because this unit had
      # not run yet. Ordering against units absent on a host is a no-op, so these are
      # safe to list unconditionally.
      "proc-fs-nfsd.mount"
      "var-lib-nfs-rpc_pipefs.mount"
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
}
