{ pkgs, lib, ... }:

{
  imports = [
    # Imported via flake.nix to avoid pkgs.path infinite recursion
  ];

  # ZFS + LUKS support
  boot.supportedFilesystems = [ "zfs" ];

  # Latest kernel for RDNA 3.5 GPU support (Framework Server Radeon 8060S)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Networking for Claude Code auth
  networking = {
    wireless.enable = lib.mkForce false;
    networkmanager.enable = true;
  };

  # All firmware (WiFi 7 ath12k, etc.)
  hardware.enableAllFirmware = true;

  # Load amdgpu early for RDNA 3.5 display (Framework Server)
  boot.initrd.kernelModules = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    # Claude assistant
    unstable.claude-code

    # ZFS + LUKS partitioning workflow
    parted
    gptfdisk
    dosfstools
    cryptsetup
    tpm2-tss

    # Essentials
    jq  # required by nixos-install --flake (resolves flake URI)
    git
    neovim
    tmux
    htop
    ripgrep
    wget
    curl

    # Networking
    networkmanagerapplet
    iw

    # YubiKey + agenix
    yubikey-manager
    libfido2
    gnupg
    pinentry-curses
    age
    age-plugin-yubikey
    pam_u2f
  ];

  # Enable flakes (required for nixos-install --flake)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.zsh.enable = true;
  users.users.nixos.shell = pkgs.zsh;

  # Smart card daemon for YubiKey
  services.pcscd.enable = true;

  # SSH server for headless install option
  services.openssh.enable = true;

  # Larger console font (Framework laptop readability)
  console.font = "ter-v24n";
  console.packages = [ pkgs.terminus_font ];

  # Claude context files
  environment.etc."claude/CLAUDE.md".source = ./claude-config/CLAUDE.md;
  environment.etc."claude/LAB-REDEPLOYMENT.md".source = ./claude-config/LAB-REDEPLOYMENT.md;

  # Install scripts
  environment.etc."nixos-installer/install.sh" = {
    source = ./install.sh;
    mode = "0755";
  };
  environment.etc."nixos-installer/refresh-flake.sh" = {
    source = ./refresh-flake.sh;
    mode = "0755";
  };

  # Set up environment on boot
  system.activationScripts.installer-setup = ''
    mkdir -p /home/nixos/.claude
    ln -sf /etc/claude/CLAUDE.md /home/nixos/.claude/CLAUDE.md
    cp /etc/claude/LAB-REDEPLOYMENT.md /home/nixos/LAB-REDEPLOYMENT.md 2>/dev/null || true

    # Create .zshrc so the newuser wizard doesn't appear
    cat > /home/nixos/.zshrc <<'ZSHRC'
# Disable history expansion (! character issues)
setopt NO_BANG_HIST
ZSHRC

    chown -R nixos:users /home/nixos/.claude /home/nixos/.zshrc /home/nixos/LAB-REDEPLOYMENT.md 2>/dev/null || true
  '';

  # Convenience aliases in the default shell profile
  environment.shellAliases = {
    install-nixos = "sudo /etc/nixos-installer/install.sh";
    refresh-flake = "sudo /etc/nixos-installer/refresh-flake.sh";
  };
}
