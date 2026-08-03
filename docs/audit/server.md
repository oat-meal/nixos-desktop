# server-nixos — Audit & Host Notes

## Hardware

- **Model**: Framework Server (5U rack)
- **CPU**: AMD Ryzen AI Max+ 395, 128GB unified RAM
- **GPU**: AMD Radeon 8060S (RDNA 3.5, integrated)
- **Storage**: ZFS on LUKS2 (rpool: 2x 1TB NVMe mirror), /storage dataset on rpool
- **Network**: WiFi + Ethernet — NIC chipset/speed **UNVERIFIED**; likely **5GbE Realtek RTL8126**
  (Framework Desktop mainboard, same NIC as workstation-nixos). ⚠️ VERIFY on wired return:
  `lspci -k | grep -iA3 ethernet` + `ethtool <iface>` for negotiated speed, then record here.
- **Kernel**: `config.boot.zfs.package.latestCompatibleLinuxPackages` (ZFS-safe; resolves to
  6.12 LTS on nixpkgs 2026-06-30 — was `linuxPackages_latest`, which outran ZFS 2.3.7 at 7.1.2).
  ⚠️ VERIFY gfx1151 amdgpu/ROCm (ollama + ComfyUI) still work on 6.12 after the update deploy;
  if regressed, switch to `boot.zfs.package = pkgs.zfs_unstable` + a recent kernel.

## Pending validation — on server return (wired, post-update)
1. Confirm NIC (lspci/ethtool) → fill in the Network line above.
2. Deploy the pending update (`git pull` → `nixos-rebuild switch`); pre-flight `nix eval` now passes.
3. Verify GPU stack (ollama-rocm gfx1151 + ComfyUI) on the 6.12 LTS kernel.
4. Plan: server → CRS310-8G+2S+IN **2.5G copper** port (5GbE NIC negotiates 2.5G; fine for
   DAS-backed NFS). DAS is direct-attached — no switch port needed (see vault Storage-Migration).

## Networking / switch plan
- **Switch (ordered):** MikroTik **CRS310-8G+2S+IN** — 8× 2.5G RJ45 + 2× SFP+ (10G), fanless,
  RouterOS (export config → git). Office switch, uplinked to the router via a 200ft Cat6A run
  through the crawlspace (in conduit, off the ground). All hosts on plain 2.5G copper ports.
- **5GbE note:** both server and workstation are (likely) 5GbE RTL8126; on 2.5G copper they
  negotiate 2.5G — plenty for these workloads (models load once + stay GPU-resident; DAS-NFS
  rarely saturates 2.5G). 5GBASE-T isn't a switch tier — full 5G needs a 10GBASE-T port.
- **UPGRADE PATH (only if 2.5G becomes limiting):** add a MikroTik **CRS304-4XG-IN** (~$199,
  4× 10GBASE-T, fanless, does 1/2.5/5/10G) as a 10G "fast lane." Put workstation + server
  (+ DAS host) on its 10G-copper ports → full 5G between them; uplink the CRS304 to the CRS310
  via **SFP+ DAC cable** (10G). Keeps everything MikroTik + fanless; spend the extra only when
  a concrete WS↔server transfer need appears. (Single-box 8-port fanless 5G copper doesn't exist
  in MikroTik's line — CRS312 is 8×10G-RJ45 but rackmount + active fan.)

## Host-Specific Configuration

- **Role**: Headless home server
- **Remote access**: SSH and Mosh (wg0-only, key-only, no root)
- **Sudo**: Scoped passwordless (nixos-rebuild, nix, systemctl, git, zfs, zpool, udevadm)
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
| AdGuard Home Web UI | 3000 | TCP | wg0 only |
| Jellyfin | 8096 | TCP | all |
| Ollama API | 11434 | TCP | wg0 only |

## Authorized SSH Keys

- `<user>@workstation-nixos`
- `<user>@laptop-nixos`
- `<user>@server-nixos`

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

### 2026-06-03 — Full Configuration Audit

**Status**: Healthy after remediation

**Remediated:**

| Issue | Resolution |
|-------|-----------|
| SSH bound to 0.0.0.0 | Added `ListenAddress = 10.100.0.2` (WireGuard IP only) |
| Ollama/AdGuard web UI open globally | Moved to wg0-only firewall (DNS + Jellyfin stay global) |
| No `logRefusedConnections` | Enabled |
| LLMNR enabled | Disabled (unnecessary attack surface) |
| Podman enabled with no containers | Removed Podman, podman group, podman sudo rule |
| Commented-out Samba block | Removed |
| SSH/sudo/ZFS config duplicated | Extracted to shared modules |
| SMART/smartmontools/lm_sensors/htop duplicated | Consolidated to shared modules and core packages |
| Host resolution used DHCP LAN IPs | Switched to WireGuard mesh IPs |

### 2026-06-04 — Full Audit

**Status**: Healthy

**Remediated:**

| Issue | Resolution |
|-------|-----------|
| Ollama bound to 0.0.0.0 | Bound to WireGuard IP 10.100.0.2 (defense-in-depth with firewall) |
| AdGuard web UI bound to 0.0.0.0 | Bound to WireGuard IP 10.100.0.2:3000 |
| sshd bind race during rebuild | Added systemd ordering: sshd after wireguard-wg0.service |
| Flake inputs 3 months old | Updated all inputs |

**Accepted (no action):**

| Issue | Rationale |
|-------|-----------|
| PAM auth failures from LAN IPs (<lan-subnet>) | SSH correctly rejected — not listening on LAN |
| `PAM user mismatch` during rebuild | Stale SSH session, transient |
| WireGuard `REPLACE-WITH-*-PUBLIC-KEY` errors | Historical, from pre-git-crypt-unlock rebuilds |
