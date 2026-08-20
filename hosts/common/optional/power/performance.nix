# Desktop power configuration
# Always-on, performance-focused, suspend disabled

{ pkgs, lib, ... }:

{
  # Performance CPU governor
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Disable suspend - AMD Ryzen 9950X (Zen 5) has Linux suspend/wake issues
  # (26.05: systemd.sleep.extraConfig was removed in favour of the settings attrset.)
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowSuspendThenHibernate = "no";
    AllowHybridSleep = "no";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandlePowerKey = "poweroff";
  };

  # zram swap (conservative for high-RAM desktop)
  zramSwap = {
    enable = true;
    memoryPercent = lib.mkDefault 10;
    algorithm = "zstd";
  };

  # Disable hardware power management (prevents deep sleep issues)
  systemd.services.disable-hardware-pm = {
    description = "Disable hardware power management on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "disable-hardware-pm" ''
        # Force GPU to high performance mode
        for gpu in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
          if [ -f "$gpu" ]; then
            echo "high" > "$gpu" 2>/dev/null || true
          fi
        done

        # Disable PCI device runtime power management
        for pci in /sys/bus/pci/devices/*/power/control; do
          if [ -f "$pci" ]; then
            echo "on" > "$pci" 2>/dev/null || true
          fi
        done
      '';
    };
  };

  # Reduced shutdown timeout
  systemd.settings.Manager.DefaultTimeoutStopSec = "30s";
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=30s
  '';
}
