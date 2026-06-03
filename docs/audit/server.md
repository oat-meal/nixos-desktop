# server-nixos — Audit & Host Notes

## Hardware

- **Model**: Framework Server (5U rack)
- **CPU**: AMD Ryzen AI Max+ 395, 128GB unified RAM
- **GPU**: AMD Radeon 8060S (RDNA 3.5, integrated)
- **Storage**: ZFS on LUKS2 (rpool: 2x 1TB NVMe mirror), /storage dataset on rpool
- **Network**: WiFi + Ethernet
- **Kernel**: `linuxPackages_latest`

## Host-Specific Configuration

- **Role**: Headless home server
- **Remote access**: SSH and Mosh (wg0-only, key-only, no root)
- **Sudo**: Scoped passwordless (nixos-rebuild, nix, systemctl, git, zfs, zpool, podman, udevadm)
- **Services**: Ollama (ROCm GPU), Jellyfin, AdGuard Home, NFS server
- **NFS**: Exports `/storage` to WireGuard subnet (root_squash)
- **ZFS ARC**: 32GB
- **ZFS maintenance**: Monthly scrub, auto-snapshots (frequent/hourly/daily/weekly/monthly)
- **Security**: Fail2ban, SSH hardened (MaxAuthTries=3, no X11/TCP forwarding), kernel hardening, audit logging, SMART monitoring

## Services & Ports

| Service | Port | Protocol | Interface |
|---------|------|----------|-----------|
| SSH | 22 | TCP | wg0 only |
| Mosh | 60000-60010 | UDP | wg0 only |
| NFS | 111, 2049 | TCP/UDP | wg0 only |
| AdGuard DNS | 53 | TCP/UDP | all |
| AdGuard Home Web UI | 3000 | TCP | all |
| Jellyfin | 8096 | TCP | all |
| Ollama API | 11434 | TCP | all |

## Authorized SSH Keys

- `oat@workstation-nixos`
- `oat@laptop-nixos`
- `oat@server-nixos`

---

## Audit History

### 2026-06-02 — Initial Deployment

- Deployed via USB thumb drive from workstation
- Issues encountered during deploy: see deployment-issues notes
- NFS server enabled, SSH key-based access confirmed from workstation and laptop

### 2026-06-02 — Security Hardening

- SSH hardened: MaxAuthTries=3, ClientAliveInterval, no X11/TCP forwarding
- Passwordless sudo scoped to management commands only
- Kernel hardening module added (sysctl, audit logging, persistent journal)
- ZFS auto-scrub and auto-snapshots enabled
- SMART disk monitoring enabled
- Fail2ban added for SSH brute force protection
- NFS switched to root_squash

### 2026-06-03 — Network Hardening

- SSH and Mosh restricted to WireGuard mesh (wg0-only, `openFirewall = false`)
- NFS export moved from LAN subnet to WireGuard subnet
- NFS firewall ports moved to wg0 interface
- Home Assistant container removed (not in use)
- sops-nix added for WireGuard private key management
- Full SSH mesh established (all host keys authorized)
