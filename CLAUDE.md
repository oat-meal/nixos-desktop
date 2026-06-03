# NixOS Lab — Claude Code Context

## Host Detection

Run `hostname` at conversation start to determine context.

| Hostname | Host Doc | Purpose |
|----------|----------|---------|
| `workstation-nixos` | `docs/audit/workstation.md` | Gaming workstation |
| `laptop-nixos` | `docs/audit/laptop.md` | Framework 13 laptop |
| `server-nixos` | `docs/audit/server.md` | Home server |

## Repository

- **Location**: `/etc/nixos/`
- **Remote**: `git@github.com:oat-meal/nixos-lab.git` (SSH)
- **Type**: Nix Flakes with Home Manager
- **Channel**: nixpkgs-25.11 stable, selective unstable overlay (`pkgs.unstable.<pkg>`)
- **Secrets**: `secrets/network.nix` encrypted via git-crypt (see Secrets section)

## Structure

```
hosts/
├── common/
│   ├── core/          # Required on ALL hosts (boot, locale, networking, nix, packages, shell, users)
│   └── optional/      # Mix-in modules (desktop/, gaming/, hardware/, networking/, power/, security/, storage/)
├── workstation/       # Gaming workstation config
├── laptop/            # Framework 13 config
├── server/            # Home server

home/
├── oat/               # User-specific Home Manager config
└── common/optional/   # Shared HM modules (desktop/, security/, user-packages.nix, theme.nix)

secrets/
├── network.nix        # IPs, public keys, device IDs (git-crypt, build-time)
├── network.nix.example # Template with placeholders
├── secrets.yaml       # WireGuard private keys (sops-nix, runtime)
└── init-sops.sh       # Helper to collect and encrypt WireGuard keys

installer/             # Custom installer ISO
docs/audit/            # Per-host audit docs
```

## Deployment

### Local rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)
```

### Deploy script

```bash
# Local only (default)
bash /etc/nixos/deploy.sh

# Specific remote host
bash /etc/nixos/deploy.sh server-nixos

# All hosts (local + push + rebuild remotes)
bash /etc/nixos/deploy.sh all
```

### Manual remote rebuild

```bash
ssh server-nixos "sudo git -C /etc/nixos -c core.sshCommand='ssh -i /home/oat/.ssh/id_ed25519 -o IdentitiesOnly=yes' pull --rebase && sudo nixos-rebuild switch --flake /etc/nixos#server-nixos"
```

## Host Access Map

```
workstation-nixos ──SSH/wg0──> server-nixos  (10.100.0.2)
workstation-nixos ──SSH/wg0──> laptop-nixos  (10.100.0.3)
laptop-nixos      ──SSH/wg0──> server-nixos  (10.100.0.2)
```

All SSH access is restricted to WireGuard mesh (`wg0`, 10.100.0.0/24). Syncthing syncs over LAN.

## Secrets

Two layers:

- **git-crypt** (build-time): `secrets/network.nix` — IPs, public keys, device IDs. Plaintext in working tree, encrypted in git. Imported by Nix modules at evaluation.
- **sops-nix** (runtime): `secrets/secrets.yaml` — WireGuard private keys. Encrypted via age, decrypted to `/run/secrets/` at system activation. Age keys derived from SSH host keys (`/etc/ssh/ssh_host_ed25519_key`).

### Committing changes to git-crypt files

```bash
nix-shell -p git-crypt --run 'git add -A && git commit -m "message"'
```

### Editing sops secrets

```bash
nix-shell -p sops age ssh-to-age --run 'sops secrets/secrets.yaml'
```

### Unlocking git-crypt after a fresh clone

```bash
git-crypt unlock ~/.config/git-crypt/nixos-lab.key
```

The git-crypt key is synced to all hosts via Syncthing (`~/.config/git-crypt/`). sops-nix uses SSH host keys automatically.

## Troubleshooting

### Build fails with "access to absolute path forbidden"
Flake pure evaluation blocks absolute paths. All imports must be relative. Secrets must be tracked in git (git-crypt handles encryption).

### WireGuard handshake not completing
Check `rp_filter` — Linux uses `max(all, interface)`. Both `net.ipv4.conf.all.rp_filter` and `net.ipv4.conf.wg0.rp_filter` must be `2` (loose). The wireguard.nix module handles this with `lib.mkForce`.

### Service not restarting after rebuild
Some services (WireGuard, Syncthing) need manual restart: `sudo systemctl restart wireguard-wg0.service`

### Firewall interface patterns
NixOS firewall defaults to iptables backend (unless `networking.nftables.enable = true`). In iptables, `+` is the wildcard suffix; in nftables, `*` is. The NixOS `interfaces` option passes the key directly to the backend. WireGuard interface `wg0` must be listed explicitly if SSH should be reachable over the mesh.

## Key Conventions

- **Module priority**: `lib.mkDefault` for common defaults, `lib.mkForce` for host overrides
- **Unstable packages**: `pkgs.unstable.<package>` (overlay in flake.nix)
- **Desktop**: Niri scrollable tiling Wayland compositor
- **Theme**: Catppuccin Macchiato system-wide
- **Browser**: Zen Browser
- **Shell**: Zsh with Oh-My-Zsh
- **User**: Single user `oat` with Home Manager
- **Passwordless sudo**: All hosts have scoped NOPASSWD for nixos-rebuild, nix*, systemctl, git, zfs, zpool

## Documentation Style

- Factual, specification-focused language
- Replace "optimized/tuned/enhanced" with "configured/specified/set"
- State technical specifications, not performance promises
- Always provide single-line commands for copy/paste (no unnecessary line breaks)

## Symlink Setup

This file lives in the repo and should be symlinked on each host:

```bash
ln -sf /etc/nixos/CLAUDE.md ~/.claude/CLAUDE.md
```
