# Steam configuration
# Steam client with Proton-GE support

{ config, pkgs, ... }:

{
  hardware.steam-hardware.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Steam environment variables
  environment.sessionVariables = {
    STEAM_FRAME_FORCE_CLOSE = "1";
  };

  # Clean stale Steam PID on activation
  system.activationScripts.steamCleanup = let
    homeDir = config.users.users.oat.home;
  in ''
    rm -f ${homeDir}/.steam/steam.pid
  '';
}
