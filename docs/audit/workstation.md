# workstation-nixos — Audit & Host Notes

## Hardware

- **CPU**: AMD Ryzen 9950X (Zen 5, 16-core, 32-thread)
- **GPU**: AMD Radeon RX 9070 XT (RDNA 4, Navi 48)
- **RAM**: 64GB DDR5
- **Storage**: ZFS on LUKS2 (rpool: ROOT/nixos, home, nix, log, swap zvol) + storage pool (2x NVMe LUKS2)
- **Network**: WiFi 7 (Qualcomm WCN785x, ath12k) + 5GbE Ethernet (RTL8126)
- **Kernel**: `linuxPackages_latest` (RDNA 4 requires recent kernel)

## Host-Specific Configuration

- **Suspend**: Disabled (Zen 5 hardware issue)
- **Power**: Always-on, performance governor, all power saving disabled
- **GameMode**: 12-core pinning (4 reserved for system)
- **SSH**: wg0-only, key-only, fail2ban (`openFirewall = false`, `ListenAddress = 10.100.0.1`)
- **Sudo**: Scoped passwordless (nixos-rebuild, nix, systemctl, git, zfs, zpool)
- **NFS mount**: `/mnt/server` via WireGuard (10.100.0.2)
- **DisplayLink**: EVDI module for USB displays
- **nix-ld**: Enabled for Fightcade, AppImages
- **Flatpak**: Enabled (Fightcade)

## Filesystem

| Mount | ZFS Dataset | Pool |
|-------|-------------|------|
| `/` | `rpool/ROOT/nixos` | rpool (NVMe, LUKS2) |
| `/home` | `rpool/home` | rpool |
| `/nix` | `rpool/nix` | rpool |
| `/var/log` | `rpool/log` | rpool |
| swap | `rpool/swap` (zvol) | rpool |
| `/storage` | `storage` | storage (2x NVMe, LUKS2) |
| `/storage/media` | `storage/media` | storage |
| `/storage/steam` | `storage/steam` | storage |

## Peripherals

- Xbox Wireless Controllers
- PS5 DualSense, PS4 DualShock
- Meta Quest 3 (USB)
- ASUS ROG devices
- Shure MV7+ (USB audio)
- FiiO K7 (USB DAC)
- Elgato Prompter (DisplayLink)

## Troubleshooting

### Steam won't launch
```bash
journalctl -u steam --no-pager
rm -f ~/.steam/steam.pid
steam
```

### Graphics issues
```bash
vulkaninfo --summary | head -30
glxinfo | grep "direct rendering"
```

### WiFi (ath12k)
```bash
ip link show
lsmod | grep ath
cat /sys/class/net/wl*/device/power/control
```

WiFi shutdown cleanup service exists for ath12k driver issues (`systemd.services.wifi-shutdown-cleanup`).

---

## Audit History

### 2026-04-06 — Full Configuration Audit

**Status**: Healthy after remediation

**Remediated:**

| Issue | Resolution | Files Changed |
|-------|-----------|---------------|
| Hardcoded home path in steam.nix | Use `config.users.users.oat.home` | `gaming/steam.nix` |
| No garbage collection | Added weekly GC, 30-day retention | `core/nix.nix` |
| Timezone mismatch (UTC vs Denver) | System timezone → America/Denver | `core/locale.nix` |
| Unstable overlay defined 3 times | Kept flake.nix only | Deleted `overlays/`, `modules/unstable-packages.nix` |
| Logrotate disabled | Re-enabled | `hosts/workstation/default.nix` |
| Duplicate Wayland session vars | Removed from graphics.nix | `gaming/graphics.nix` |
| GPG agent configured twice | System-level only | `home/oat/default.nix`, `yubikey/default.nix` |
| Redundant `iwlwifi.power_scheme` | Removed | `hosts/workstation/default.nix` |
| GameMode core_count string type | Changed to int `12` | `hosts/workstation/default.nix` |
| Duplicate theme files | Consolidated to common | `home/oat/default.nix` |
| Custom Steam desktop entry | Removed (use upstream) | `gaming/steam.nix` |
| Legacy `modules/` directory | Deleted, migrated imports | Multiple |
| Browser stack (Firefox, Brave) | Consolidated to Zen Browser | Multiple |
| Claude Code on stable | Moved to unstable | `desktop/apps.nix` |
| Wallpaper fails silently | Power-aware wallpaper script | `niri/home.nix` |
| 1,440 old generations | `nix-collect-garbage --delete-older-than 30d` | Manual |

**Follow-up (same session):**

| Issue | Resolution |
|-------|-----------|
| mpvpaper startup race | Added to niri system packages |
| Duplicate packages (wl-clipboard, htop, ripgrep) | Removed from user-packages |
| wireguard-tools in 3 modules | Kept in nordvpn.nix only |
| Waybar VPN script sudo spam | Replaced `wg show` with `ip link show` |
| Broken steam.desktop symlink | Deleted |
| 5 `.hm_bak` files | Deleted |
| Stale Brave .desktop file | Deleted |

**Accepted (no action):**

| Issue | Rationale |
|-------|-----------|
| Steam split-lock warnings | Upstream Valve bug |
| Unpinned niri-flake | flake.lock pins it |
| `linuxPackages_latest` | RDNA 4 requires it |
| dbus/gnome-keyring warnings | Cosmetic |

### 2026-06-02 — Reimage + Security Hardening

- Reimaged with ZFS on LUKS2 (migrated from Btrfs)
- Kernel hardening module added (sysctl, audit logging, persistent journal)
- ZFS auto-scrub and auto-snapshots enabled
- WiFi driver corrected: removed iwlwifi, fixed ath11k → ath12k
- udev rule to hide ZFS members from Thunar sidebar
- NFS automount to server at /mnt/server
- Steam library added on /storage/steam (ZFS dataset)
- Steam dedicated server firewall ports disabled

### 2026-06-03 — Network Hardening

- SSH server added (wg0-only, `openFirewall = false`, fail2ban)
- All host keys authorized (full mesh)
- Scoped passwordless sudo added
- NFS mount changed from LAN hostname to WireGuard IP (10.100.0.2)
- sops-nix added for WireGuard private key management
- Syncthing active (claude-context, git-crypt-keys)

### 2026-06-03 — Full Configuration Audit

**Status**: Healthy after remediation

**Remediated:**

| Issue | Resolution |
|-------|-----------|
| SSH/sudo/ZFS config duplicated across hosts | Extracted shared modules: `ssh.nix`, `sudo.nix`, `zfs-maintenance.nix` |
| SSH bound to 0.0.0.0 (defense-in-depth) | Added `ListenAddress = 10.100.0.1` (WireGuard IP only) |
| No SMART monitoring | Added to shared `zfs-maintenance.nix` |
| `/etc/hosts` used DHCP LAN IPs | Switched to WireGuard mesh IPs for host resolution |
| `librewolf` still installed | Removed (consolidated to Zen Browser) |
| Duplicate `catppuccin-cursors` in apps.nix | Removed (provided by theme.nix) |
| Duplicate `wireless-regdb` in framework.nix | Removed (provided by wifi.nix) |
| `lm_sensors` in user-packages and server | Moved to core packages (all hosts) |
| Logrotate only on workstation | Moved to shared `zfs-maintenance.nix` (all hosts) |

**Accepted (no action):**

| Issue | Rationale |
|-------|-----------|
| `nix*`/`git`/`systemctl` sudo wildcards | Effectively full root, acceptable for single-user lab |
| `hostId` not in host config | Already in `hardware-configuration.nix` (installer-generated) |
