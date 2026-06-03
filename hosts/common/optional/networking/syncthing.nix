# Syncthing — continuous file sync across lab hosts
# Syncs ~/.claude/ for shared Claude context across all machines
#
# After first deployment, get device IDs with:
#   syncthing cli show system | grep myID
# Then update secrets/network.nix and redeploy.

{ config, lib, ... }:

let
  secrets = import ../../../../secrets/network.nix;
  hostname = config.networking.hostName;
  devices = secrets.syncthing;

  # All hosts except this one
  otherHosts = lib.filterAttrs (name: _: name != hostname) devices;
in
{
  services.syncthing = {
    enable = true;
    user = secrets.user;
    group = "users";
    dataDir = "/home/${secrets.user}";
    configDir = "/home/${secrets.user}/.config/syncthing";
    openDefaultPorts = true;

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      devices = lib.mapAttrs (name: id: {
        inherit id;
      }) otherHosts;

      folders = {
        "claude-context" = {
          path = "/home/${secrets.user}/.claude";
          devices = lib.attrNames otherHosts;
          versioning = {
            type = "simple";
            params.keep = "5";
          };
          ignorePerms = false;
        };
      };

      options = {
        urAccepted = -1; # Disable usage reporting
        localAnnounceEnabled = true; # LAN discovery
        globalAnnounceEnabled = false; # LAN only
        relaysEnabled = false; # No relay servers
      };
    };
  };
}
