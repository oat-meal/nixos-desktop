# User configuration
# Defines the primary user - hosts extend extraGroups as needed

{ pkgs, ... }:

{
  users.users.oat = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
  };
}
