# System Audit Process

Repeatable audit procedure for all NixOS lab hosts.

## When to Audit

- After major configuration changes
- After flake input updates
- Monthly maintenance check
- When adding a new host

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
ip link show | grep -E "^[0-9]"
resolvectl status 2>/dev/null | head -15
ss -tlnp 2>/dev/null  # listening ports
```

### 7. Desktop State

```bash
pgrep -a niri
pgrep -a waybar
pgrep -a mako
pgrep -a pipewire
```

### 8. Stale Files

```bash
# Broken symlinks in applications
find ~/.local/share/applications -xtype l 2>/dev/null

# Home Manager backup files
find ~ -name "*.hm_bak" -maxdepth 3 2>/dev/null

# Coredumps
coredumpctl list --no-pager 2>/dev/null | tail -10
```

### 9. Configuration

```bash
# Evaluate without building (catches syntax/type errors)
nix eval "/etc/nixos#nixosConfigurations.$(hostname).config.system.build.toplevel.drvPath"

# Check for duplicate packages, stale references, etc.
# (Use Claude Code or manual review)
```

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

## Cross-Host Checks

After auditing individual hosts, verify shared modules are consistent:

- `hosts/common/core/` settings apply correctly to all hosts
- `hosts/common/optional/` modules don't have host-specific assumptions
- `home/common/optional/` works for all users/hosts
- No hardcoded paths (use `config.users.users.<name>.home`, etc.)

## Files

- `known-states.md` — Shared known states across all hosts (do not flag)
- `workstation.md` — workstation-nixos audit history and host-specific notes
- `laptop.md` — laptop-nixos audit history and host-specific notes
