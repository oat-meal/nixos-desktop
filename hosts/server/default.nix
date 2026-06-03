# Framework Server — headless home server
# AMD Ryzen AI Max+ 395, 128GB unified RAM, 2x 1TB NVMe (ZFS mirror)
# Services: Ollama, Jellyfin, AdGuard Home, Home Assistant, NFS/Samba

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # Core (required)
    ../common/core

    # Hardware
    ../common/optional/hardware/amd.nix

    # Networking
    ../common/optional/networking/syncthing.nix
    ../common/optional/networking/wifi.nix
    ../common/optional/networking/wireguard.nix

    # Security
    ../common/optional/security/luks.nix
    ../common/optional/security/hardening.nix
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
  ## Remote access
  ################################
  services.openssh = {
    enable = true;
    openFirewall = false;  # SSH restricted to wg0 below
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      AllowTcpForwarding = false;
      GatewayPorts = "no";
    };
  };

  # Mosh for roaming SSH (survives WiFi drops, laptop sleep)
  programs.mosh = {
    enable = true;
    openFirewall = false;  # Mosh restricted to wg0 below
  };

  # Fail2ban — rate-limit SSH brute force attempts
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment.enable = true;
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
  virtualisation.oci-containers.containers = {
    home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [ "/var/lib/hass:/config" ];
      ports = [ "8123:8123" ];
    };
  };

  ################################
  ## NFS + Samba
  ################################
  services.nfs.server = {
    enable = true;
    exports = let
      secrets = import ../../secrets/network.nix;
    in ''
      /storage  ${secrets.wireguard.meshSubnet}(rw,sync,no_subtree_check,root_squash)
    '';
  };

  # services.samba = {
  #   enable = true;
  #   settings = {
  #     global = {
  #       workgroup = "LAB";
  #       "server string" = "server-nixos";
  #       security = "user";
  #     };
  #     share = {
  #       path = "/tank/share";
  #       browseable = true;
  #       "read only" = false;
  #       "valid users" = "oat";
  #     };
  #     media = {
  #       path = "/tank/media";
  #       browseable = true;
  #       "read only" = true;
  #       "valid users" = "oat";
  #     };
  #   };
  # };

  ################################
  ## Firewall
  ################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      53     # AdGuard DNS
      3000   # AdGuard Home web UI
      8096   # Jellyfin
      8123   # Home Assistant
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
  ## ZFS maintenance
  ################################
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;    # 15-min snapshots, keep 4
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
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

  # Scoped passwordless sudo for headless remote management
  security.sudo.extraRules = [{
    users = [ "oat" ];
    commands = [
      { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/nix*"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/git"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zfs"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zpool"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/podman"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/udevadm"; options = [ "NOPASSWD" ]; }
    ];
  }];
  users.users.oat.openssh.authorizedKeys.keys = let
    secrets = import ../../secrets/network.nix;
  in lib.attrValues secrets.sshKeys;
}
