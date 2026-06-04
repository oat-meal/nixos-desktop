# System Audit Process

Repeatable audit procedure for all NixOS lab hosts.

## When to Audit

- After major configuration changes
- After flake input updates
- Monthly maintenance check
- When adding a new host

## Flake Input Updates

Update monthly to stay current with security patches:

```bash
sudo nix flake update /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
# Test, then deploy to other hosts
bash /etc/nixos/deploy.sh all
```

Check input ages during audits:
```bash
nix flake metadata /etc/nixos 2>/dev/null | grep -A20 "Inputs:"
```

## Audit Checklist

Run on each host. Record results in the host's audit file (`docs/audit/<hostname>.md`).

### 1. Pre-flight

```bash
# Which host are we auditing?
hostname

# Current system generation
nixos-rebuild list-generations | tail -5

# Flake input ages
nix flake metadata /etc/nixos 2>/dev/null | grep -A20 "Inputs:"
```

### 2. Service Health

```bash
# Failed units
systemctl --failed
systemctl --user --failed

# Active timers (GC, logrotate, fstrim)
systemctl list-timers --all --no-pager
```

### 3. Journal Errors

Filter out known states (see `known-states.md`):
```bash
journalctl -p err -b --no-pager \
  | grep -v -E "split.lock|pulse|gkr-pam|MES|amdgpu|pidns|gtk_widget_get_scale" \
  | tail -40
```

### 4. Disk & Store

```bash
df -h
du -sh /nix/store
nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l
```

### 5. Hardware

```bash
sensors 2>/dev/null | head -30
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null
```

### 6. Network

```bash
# Interfaces
ip link show | grep -E "^[0-9]"

# DNS
resolvectl status 2>/dev/null | head -15

# Listening ports
ss -tlnp 2>/dev/null

# WireGuard mesh
sudo wg show wg0

# Syncthing status
systemctl is-active syncthing
```

### 7. Secrets

```bash
# sops-nix secrets decrypted
ls -la /run/secrets/

# WireGuard using sops-managed key
systemctl status wireguard-wg0.service | head -10
```

### 8. Firewall

```bash
# Verify SSH restricted to wg0
sudo iptables -L nixos-fw -n -v 2>/dev/null | grep -E '22|wg0'

# Verify LAN SSH blocked (run from another host)
# nc -z -w 3 <LAN_IP> 22
```

### 9. Desktop State (desktop hosts only)

```bash
pgrep -a niri
pgrep -a waybar
pgrep -a mako
pgrep -a pipewire
```

### 10. Stale Files

```bash
# Broken symlinks in applications
find ~/.local/share/applications -xtype l 2>/dev/null

# Home Manager backup files
find ~ -name "*.hm_bak" -maxdepth 3 2>/dev/null

# Coredumps
coredumpctl list --no-pager 2>/dev/null | tail -10
```

### 11. Configuration

```bash
# Evaluate without building (catches syntax/type errors)
nix eval "/etc/nixos#nixosConfigurations.$(hostname).config.system.build.toplevel.drvPath"
```

## Cross-Host Checks

After auditing individual hosts, verify connectivity and shared state:

```bash
# WireGuard mesh — full connectivity
ssh -o ConnectTimeout=5 oat@10.100.0.1 "echo workstation OK"
ssh -o ConnectTimeout=5 oat@10.100.0.2 "echo server OK"
ssh -o ConnectTimeout=5 oat@10.100.0.3 "echo laptop OK"

# LAN SSH blocked on all hosts
nc -z -w 3 <server-lan-ip> 22 && echo "server LAN SSH OPEN" || echo "server LAN SSH blocked"
nc -z -w 3 <laptop-lan-ip> 22 && echo "laptop LAN SSH OPEN" || echo "laptop LAN SSH blocked"

# Syncthing connected
curl -s http://localhost:8384/rest/system/connections 2>/dev/null | grep -c '"connected":true'

# NFS over WireGuard (from workstation)
ls /mnt/server/ && echo "NFS OK" || echo "NFS FAIL"
```

Also verify shared modules:

- `hosts/common/core/` settings apply correctly to all hosts
- `hosts/common/optional/` modules don't have host-specific assumptions
- `home/common/optional/` works for all users/hosts
- No hardcoded paths (use `config.users.users.<name>.home`, etc.)

## Recording Results

Add findings to `docs/audit/<hostname>.md` under a dated heading:

```markdown
### YYYY-MM-DD — Audit Summary

**Status**: Healthy / Issues Found

**New Issues:**
| Issue | Severity | Resolution |
|-------|----------|------------|

**Resolved Since Last Audit:**
- ...
```

## Files

- `known-states.md` — Shared known states across all hosts (do not flag)
- `workstation.md` — workstation-nixos audit history and host-specific notes
- `laptop.md` — laptop-nixos audit history and host-specific notes
- `server.md` — server-nixos audit history and host-specific notes
