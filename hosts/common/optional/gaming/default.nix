# Gaming module
# Imports all gaming-related configuration

{ ... }:

{
  imports = [
    ./steam.nix
    ./steam-split-lock-fix.nix
    ./gamemode.nix
    ./graphics.nix
    ./launchers.nix
  ];
}
