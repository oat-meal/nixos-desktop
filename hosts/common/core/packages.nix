# Base packages for all hosts
# Minimal CLI tools that every system should have

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core CLI tools
    git
    git-crypt
    wget
    curl
    neovim
    htop
    ripgrep

    # System utilities
    pciutils
    usbutils
    lsb-release
  ];
}
