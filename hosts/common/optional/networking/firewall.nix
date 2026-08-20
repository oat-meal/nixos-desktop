# Firewall configuration
# Default-deny inbound, permissive outbound
# Suitable for desktop use: browsing, gaming, coding

{ lib, ... }:

{
  networking.firewall = {
    enable = true;

    # No inbound TCP ports needed for desktop use
    allowedTCPPorts = [ ];

    # mDNS for local device discovery (printers, Chromecast, etc.)
    allowedUDPPorts = [ 5353 ];

    # Log denied packets (rate-limited to avoid spam)
    logRefusedConnections = lib.mkDefault true;

    # Gaming: Steam peer-to-peer, voice chat use high UDP ports
    allowedUDPPortRanges = [
      { from = 27000; to = 27100; }  # Steam
    ];
  };

  # Disable LLMNR (Windows name resolution, unnecessary attack surface)
  services.resolved.settings.Resolve.LLMNR = lib.mkDefault "false";
}
