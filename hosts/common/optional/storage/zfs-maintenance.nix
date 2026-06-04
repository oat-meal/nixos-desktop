# ZFS maintenance — scrub, snapshots, SMART monitoring
# Shared across all ZFS hosts

{ pkgs, ... }:

{
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };

  services.logrotate.enable = true;

  # SMART disk health monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  environment.systemPackages = with pkgs; [
    smartmontools
  ];
}
