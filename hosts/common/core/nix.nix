# Nix configuration
# Flakes, experimental features, and nixpkgs settings

{ lib, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Obsidian bundles an EOL Electron that nixpkgs flags as insecure. Obsidian is
  # a local markdown editor (limited attack surface), so permit this specific
  # version rather than a blanket allowInsecure. Revisit/remove when Obsidian in
  # nixpkgs moves to a supported Electron.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];
}
