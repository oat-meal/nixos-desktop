# ZFS maintenance — scrub and snapshots
# Shared across all ZFS hosts

{ ... }:

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
}
