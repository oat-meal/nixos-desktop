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
- **Remote access**: SSH (key-only, no root), Mosh
- **Sudo**: Scoped passwordless (nixos-rebuild, nix, systemctl, git, zfs, zpool, podman, udevadm)
- **Services**: Ollama (ROCm GPU), Jellyfin, AdGuard Home, Home Assistant (Podman, isolated network), NFS server
- **NFS**: Exports `/storage` to LAN subnet (root_squash)
- **ZFS ARC**: 32GB
- **ZFS maintenance**: Monthly scrub, auto-snapshots (frequent/hourly/daily/weekly/monthly)
- **Security**: Fail2ban, SSH hardened (MaxAuthTries=3, no X11/TCP forwarding), kernel hardening, audit logging, SMART monitoring

## Services & Ports

| Service | Port | Protocol |
|---------|------|----------|
| SSH | 22 | TCP |
| AdGuard DNS | 53 | TCP/UDP |
| AdGuard Home Web UI | 3000 | TCP |
| Jellyfin | 8096 | TCP |
| Home Assistant | 8123 | TCP |
| Ollama API | 11434 | TCP |
| NFS | 111, 2049 | TCP/UDP |
| Mosh | 60000-60010 | UDP |

## Authorized SSH Keys

- `oat@workstation-nixos`
- `oat@laptop-nixos`

---

## Audit History

### 2026-06-02 — Initial Deployment

- Deployed via USB thumb drive from workstation
- Issues encountered during deploy: see deployment-issues notes
- NFS server enabled, SSH key-based access confirmed from workstation and laptop

### 2026-06-02 — Security Hardening

- SSH hardened: MaxAuthTries=3, ClientAliveInterval, no X11/TCP forwarding
- Home Assistant container isolated from host network (port mapping only)
- Passwordless sudo scoped to management commands only
- Kernel hardening module added (sysctl, audit logging, persistent journal)
- ZFS auto-scrub and auto-snapshots enabled
- SMART disk monitoring enabled
- Fail2ban added for SSH brute force protection
- NFS switched to root_squash
