# Laptop power configuration
# Battery optimization, suspend-then-hibernate, power profiles

{ lib, ... }:

{
  # UPower for battery monitoring (used by WirePlumber, the Noctalia shell, etc.)
  services.upower.enable = true;

  # Power profiles daemon (integrates with Framework)
  services.power-profiles-daemon.enable = true;

  # Enable suspend/hibernate
  powerManagement.enable = true;

  # Suspend-then-hibernate: suspends immediately, hibernates after delay
  # This prevents battery drain and overheating in bags
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "poweroff";
  };

  # Hibernate after 5 minutes of suspend
  systemd.sleep.extraConfig = ''
    AllowSuspendThenHibernate=yes
    HibernateDelaySec=5min
  '';

  # Disable USB wakeup sources to prevent spurious wakes during suspend
  # (USB-C/Type-C often triggers immediate wake on s2idle systems)
  powerManagement.powerDownCommands = ''
    # Disable USB wakeup
    for dev in /sys/bus/usb/devices/*/power/wakeup; do
      echo disabled > "$dev" 2>/dev/null || true
    done
    # Disable PCI wakeup for USB controllers (XHC)
    for dev in /sys/bus/pci/devices/*/power/wakeup; do
      if grep -q "xhci" "/sys/bus/pci/devices/$(basename $(dirname $dev))/driver" 2>/dev/null; then
        echo disabled > "$dev" 2>/dev/null || true
      fi
    done
  '';

  # zram swap for runtime (lower priority so hibernate uses disk swap)
  zramSwap = {
    enable = true;
    memoryPercent = lib.mkDefault 25;
    algorithm = "zstd";
    priority = 100;  # Lower priority than disk swap (default 5)
  };
}
