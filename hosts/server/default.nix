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
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ZFS ARC 32GB
  boot.kernelParams = [ "zfs.zfs_arc_max=34359738368" ];

  # Load amdgpu early for display during LUKS passphrase prompt (RDNA 3.5)
  boot.initrd.kernelModules = [ "amdgpu" ];

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
    # LAN accessible (firewall restricts external access)
    host = "0.0.0.0";
    port = 11434;
    # AMD GPU acceleration (Radeon 8060S, RDNA 3.5, ROCm)
    acceleration = "rocm";
  };

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
  ## Podman + containers
  ################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.oci-containers.backend = "podman";

  ################################
  ## NFS
  ################################
  services.nfs.server = {
    enable = true;
    exports = let
      secrets = import ../../secrets/network.nix;
    in ''
      /storage  ${secrets.wireguard.meshSubnet}(rw,sync,no_subtree_check,root_squash)
    '';
  };

  ################################
  ## Firewall
  ################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      53     # AdGuard DNS
      3000   # AdGuard Home web UI
      8096   # Jellyfin
      11434  # Ollama API
    ];
    allowedUDPPorts = [
      53     # AdGuard DNS
    ];
    # SSH, Mosh, and NFS only over WireGuard mesh
    interfaces."wg0".allowedTCPPorts = [ 22 111 2049 ];
    interfaces."wg0".allowedUDPPorts = [ 111 2049 ];
    interfaces."wg0".allowedUDPPortRanges = [
      { from = 60000; to = 60010; }  # Mosh
    ];
  };

  ################################
  ## SMART disk monitoring
  ################################
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  ################################
  ## Server packages
  ################################
  environment.systemPackages = with pkgs; [
    htop
    iotop
    tmux
    mosh
    smartmontools  # Disk health monitoring
    lm_sensors     # Temperature monitoring
  ];

  ################################
  ## User groups + SSH access
  ################################
  users.users.oat.extraGroups = lib.mkAfter [ "podman" ];

  # Additional passwordless sudo commands (extends shared sudo.nix)
  security.sudo.extraRules = lib.mkAfter [{
    users = [ "oat" ];
    commands = [
      { command = "/run/current-system/sw/bin/podman"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/udevadm"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
