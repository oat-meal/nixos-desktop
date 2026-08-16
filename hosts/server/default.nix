# Framework Server — headless home server
# AMD Ryzen AI Max+ 395, 128GB unified RAM, 2x 1TB NVMe (ZFS mirror)
# Services: Ollama, Jellyfin, AdGuard Home, NFS

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # Core (required)
    ../common/core

    # Hardware
    ../common/optional/hardware/amd.nix

    # Networking
    ../common/optional/networking/sops.nix
    ../common/optional/networking/ssh.nix
    ../common/optional/networking/syncthing.nix
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Security
    ../common/optional/security/luks.nix
    ../common/optional/security/hardening.nix
    ../common/optional/security/sudo.nix

    # Storage
    ../common/optional/storage/zfs-maintenance.nix
    ../common/optional/monitoring/post-rebuild-verify.nix
    ../common/optional/monitoring/update-advisor.nix

    # AI lab
    ../common/optional/ai/mcp-host-health.nix
    ../common/optional/ai/fleet-sentinel.nix
    ../common/optional/ai/open-webui.nix
    ../common/optional/ai/searxng.nix
    ../common/optional/ai/chromadb.nix
    ../common/optional/ai/lab-tools.nix
    ../common/optional/ai/lab-api.nix
    ../common/optional/ai/comfyui.nix
    ../common/optional/ai/dashboard.nix
    ../common/optional/ai/kokoro.nix
    ../common/optional/ai/ntfy.nix
  ];

  ################################
  ## Host identity
  ################################
  networking.hostName = "server-nixos";
  system.stateVersion = "25.11";
  networking.hostId = "dc598b84";

  ################################
  ## Kernel
  ################################
  # ZFS host: track the newest kernel ZFS actually supports, NOT linuxPackages_latest.
  # ZFS lags kernel releases, so `latest` periodically outruns it and marks
  # zfs-kernel broken (hit 2026-08-03: nixpkgs 2026-06-30 gave kernel 7.1.2, which
  # ZFS 2.3.7 didn't support → server config refused to evaluate). This attr always
  # resolves to a ZFS-compatible kernel, so updates can't break the storage host.
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  # ZFS ARC 32GB
  boot.kernelParams = [
    "zfs.zfs_arc_max=34359738368"
    "spl.spl_hostid=0xdc598b84"  # claim rpool with system hostid at initrd import; clears hostid-mismatch warning
  ];

  # Load amdgpu early for display during LUKS passphrase prompt (RDNA 3.5)
  boot.initrd.kernelModules = [ "amdgpu" ];

  ################################
  ## Wired-only networking
  ################################
  # This host is always wired (enp191s0, persistent NM static 192.168.10.50), so the
  # MT7925 radio stays off. With WiFi live the box was dual-homed — two default routes
  # to the same gateway, one per interface — which gives ambiguous source-address
  # selection for the wg0 endpoint and invites asymmetric routing. Blacklisting the
  # driver removes the interface outright rather than leaving an unmanaged one to be
  # re-enabled by accident.
  #
  # To restore WiFi: drop this line and rebuild. Note there is no fallback path in if
  # the wired NIC is down — that recovery is console-only.
  boot.blacklistedKernelModules = [ "mt7925e" ];

  ################################
  ## Headless — no desktop environment
  ################################

  # Larger TTY font for direct-attach troubleshooting
  console.font = "ter-v24n";
  console.packages = [ pkgs.terminus_font ];

  ################################
  ## Remote access (extends shared ssh.nix)
  ################################
  services.openssh.settings.GatewayPorts = "no";

  # Mosh for roaming SSH (survives WiFi drops, laptop sleep)
  programs.mosh = {
    enable = true;
    openFirewall = false;
  };

  ################################
  ## Ollama — local LLM inference
  ################################
  services.ollama = {
    enable = true;
    # Unstable 0.24.0 ROCm — native gfx1151 support (stable 0.21.1 crashed during
    # compute on Strix Halo). Fallback ready: pkgs.unstable.ollama-vulkan.
    package = pkgs.unstable.ollama-rocm;
    # Static user (not DynamicUser) so the dedicated models dataset has stable
    # ownership and can be migrated to a future DAS pool.
    user = "ollama";
    group = "ollama";
    # Bind to WireGuard IP (firewall also restricts to wg0)
    host = "10.100.0.2";
    port = 11434;
    # AMD GPU acceleration (Radeon 8060S, RDNA 3.5, ROCm)
    acceleration = "rocm";
    # Models on a dedicated ZFS dataset (rpool/storage/ollama, recordsize=1M,
    # compression=off) — zfs send/recv to a DAS pool later, same mountpoint.
    # Point at the dataset root (already exists + owned by ollama, ZFS-persisted),
    # so ollama creates blobs/manifests there — no subdir tmpfiles race.
    models = "/storage/ollama";
    # Shared backend: two players + Open WebUI + agents.
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_KEEP_ALIVE = "30m";
      # 0.24 defaults the 70B to a 256K context; with NUM_PARALLEL=2 that KV cache
      # exceeds RAM. Cap to a sane default (per-request num_ctx can still go higher).
      OLLAMA_CONTEXT_LENGTH = "8192";
      # Flash attention: faster attention + smaller KV cache on ROCm. Speeds up
      # generation and lets the warm model use less VRAM.
      OLLAMA_FLASH_ATTENTION = "1";
    };
  };

  # Own the models dataset for the static ollama user (ZFS persists this; the rule
  # is a safety net). The dataset is created out of band via `zfs create`.
  systemd.tmpfiles.rules = [
    "d /storage/ollama 0750 ollama ollama - -"
  ];

  ################################
  ## Jellyfin — media server
  ################################
  services.jellyfin = {
    enable = true;
    openFirewall = false; # Managed below
  };

  # VAAPI hardware transcode (Radeon 8060S)
  hardware.graphics.enable = true;

  ################################
  ## AdGuard Home — network DNS ad-blocking
  ################################
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    # Bind web UI to WireGuard IP (firewall also restricts to wg0)
    host = "10.100.0.2";
    port = 3000;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
        ];
        bootstrap_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
      filtering.enabled = true;
    };
  };

  ################################
  ## NFS
  ################################
  services.nfs.server = {
    enable = true;
    exports = let
      secrets = import ../../secrets/network.nix;
    in ''
      /storage  ${secrets.wireguard.meshSubnet}(rw,sync,no_subtree_check,root_squash,crossmnt)
    '';
  };

  ################################
  ## Firewall
  ################################
  networking.firewall = {
    enable = true;
    logRefusedConnections = true;
    # LAN-accessible services (needed by phones, TVs, other LAN clients)
    allowedTCPPorts = [
      53     # AdGuard DNS
      8096   # Jellyfin
    ];
    allowedUDPPorts = [
      53     # AdGuard DNS
    ];
    # WireGuard-only services (admin/internal)
    # 22=SSH  111/2049=NFS  3000=AdGuard-UI  11434=Ollama  8080=Open-WebUI  8888=SearXNG  8000=ChromaDB
    interfaces."wg0".allowedTCPPorts = [ 22 111 2049 3000 11434 8080 8888 8000 ];
    interfaces."wg0".allowedUDPPorts = [ 111 2049 ];
    interfaces."wg0".allowedUDPPortRanges = [
      { from = 60000; to = 60010; }  # Mosh
    ];
  };

  # Disable LLMNR (unnecessary attack surface on headless server)
  services.resolved.llmnr = "false";

  ################################
  ## Server packages
  ################################
  environment.systemPackages = with pkgs; [
    iotop
    tmux
    mosh

    # AI lab tooling
    python3
    uv
  ];

  ################################
  ## User groups + SSH access
  ################################
  # Additional passwordless sudo commands (extends shared sudo.nix)
  security.sudo.extraRules = lib.mkAfter [{
    users = [ "oat" ];
    commands = [
      { command = "/run/current-system/sw/bin/udevadm"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
