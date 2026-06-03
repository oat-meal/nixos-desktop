# laptop-nixos — Audit & Host Notes

## Hardware

- **Model**: Framework Laptop 13
- **CPU**: AMD Ryzen (8-core)
- **GPU**: AMD Radeon integrated (card1)
- **Storage**: ZFS on LUKS2 (rpool: ROOT/nixos, home, nix, log, swap zvol)
- **Kernel**: `linux_6_12` (stable LTS)

## Host-Specific Configuration

- **Suspend**: Enabled (lid switch handling)
- **Power**: power-profiles-daemon, portable power module, hibernate support
- **GameMode**: 4-core pinning (4 reserved for system), GPU device = card1
- **WiFi**: Power saving enabled (battery optimization)
- **Backlight**: `amdgpu.abmlevel=0` to prevent GPU idle lockups
- **Fingerprint**: Reader support enabled
- **Framework tools**: ectool
- **SSH**: wg0-only, key-only, fail2ban (`openFirewall = false`)
- **Sudo**: Scoped passwordless (nixos-rebuild, nix, systemctl, git, zfs, zpool)

## Differences from Workstation

| Setting | Workstation | Laptop |
|---------|-------------|--------|
| Kernel | `linuxPackages_latest` | `linux_6_12` LTS |
| Suspend | Disabled | Enabled |
| WiFi power save | Disabled | Enabled |
| CPU governor | Performance | Managed by power-profiles-daemon |
| GameMode cores | 12 | 4 |
| GameMode GPU | card0 (default) | card1 (integrated) |
| Power module | `performance.nix` | `portable.nix` + `hibernate.nix` |
| DisplayLink | Yes | No |
| nix-ld | Yes | No |
| Flatpak | Yes | No |

## Authorized SSH Keys

- `oat@workstation-nixos`
- `oat@laptop-nixos`
- `oat@server-nixos`

---

## Audit History

### 2026-04-06 — Remote Fix (from workstation audit)

**Remediated:**

| Issue | Resolution |
|-------|-----------|
| GameMode core_count string type | Changed `"4"` to int `4` |
| GPU device override added | `gpu_device = lib.mkForce 1` for card1 |

No full on-host audit performed yet. Schedule when next on laptop.

### 2026-06-02 — Reimage + Security Hardening

- Reimaged with ZFS on LUKS2 (migrated from Btrfs)
- Kernel hardening module added (sysctl, audit logging, persistent journal)
- ZFS auto-scrub and auto-snapshots enabled
- SSH enabled with fail2ban
- Workstation SSH key authorized

### 2026-06-03 — Network Hardening

- SSH restricted to WireGuard mesh (wg0-only, `openFirewall = false`)
- All host keys authorized (full mesh)
- Scoped passwordless sudo added
- sops-nix added for WireGuard private key management
- Syncthing active (claude-context, git-crypt-keys)
