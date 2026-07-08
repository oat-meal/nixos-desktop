# User configuration
# Defines the primary user - hosts extend extraGroups as needed

{ pkgs, ... }:

{
  users.users.oat = {
    isNormalUser = true;
    uid = 1000;
    # systemd-journal: journal read access for the host-health MCP + fleet tools.
    extraGroups = [ "wheel" "networkmanager" "systemd-journal" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
  };
}
