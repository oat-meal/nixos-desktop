# Core configuration - imported by ALL hosts
# These modules are required and provide base system functionality

{ ... }:

{
  imports = [
    ./nix.nix
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./packages.nix
    ./shell.nix
    ./users.nix
  ];
}
