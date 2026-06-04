# NixOS Lab

Multi-host NixOS infrastructure managed as a single Nix Flake. Declarative configurations for a personal computing environment with full-disk encryption (LUKS2 + ZFS) across all hosts.

## Hosts

| Host | Hardware | Storage | Status |
|------|----------|---------|--------|
| `workstation-nixos` | Ryzen 9950X, 64GB RAM, AMD GPU | ZFS on LUKS2 | Active |
| `laptop-nixos` | Framework 13, Ryzen, 32GB RAM | ZFS on LUKS2 | Active |
| `server-nixos` | Ryzen AI Max+ 395, 128GB RAM, AMD iGPU | ZFS on LUKS2 | Active |

## Storage Architecture

All hosts use the same disk layout:

- **LUKS2** full-disk encryption with argon2id PBKDF
- **ZFS** pools on LUKS containers (`rpool` for OS, `storage` for data where applicable)
- **ZFS datasets**: `rpool/ROOT/nixos`, `rpool/home`, `rpool/nix`, `rpool/log`
- **Swap**: ZFS zvol (`rpool/swap`) with hibernate support
- **YubiKey FIDO2** unlock support (optional, enrolled post-install)

## Quick Start

### Installation

A custom installer ISO handles partitioning, encryption, and system deployment:

```bash
# 1. Build and flash the installer USB (from an existing NixOS host)
sudo bash ~/flash-installer-usb.sh

# 2. Boot the USB on the target machine

# 3. Connect to network (NetworkManager is available)
nmtui

# 4. Run the installer
install-nixos
```

The installer will:
- Partition disks (GPT + EFI + LUKS2)
- Create ZFS pools and datasets
- Clone this flake from GitHub
- Generate hardware-configuration.nix for the target hardware
- Build and install the system

### Post-Install

```bash
# Enroll YubiKey for LUKS unlock (optional)
sudo systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto

# Set user password
passwd oat
```

## Repository Structure

```
nixos-lab/
├── flake.nix                        # Flake: all hosts + installer ISO
├── flake.lock                       # Pinned inputs
├── deploy.sh                        # Multi-host deploy script
│
├── .sops.yaml                       # sops-nix age key config
├── secrets/
│   ├── network.nix                  # IPs, public keys, device IDs (git-crypt encrypted)
│   ├── network.nix.example          # Template with placeholders
│   ├── secrets.yaml                 # Runtime secrets: WireGuard private keys (sops encrypted)
│   └── init-sops.sh                 # Helper to collect and encrypt WireGuard keys
│
├── installer/                       # Custom installer ISO
│   ├── default.nix                  # ISO system configuration
│   ├── install.sh                   # Interactive install script
│   └── refresh-flake.sh             # Pull latest flake to USB
│
├── hosts/
│   ├── common/
│   │   ├── core/                    # Required on ALL hosts
│   │   │   ├── boot.nix             # systemd-boot
│   │   │   ├── locale.nix           # Locale/timezone
│   │   │   ├── networking.nix       # NetworkManager, host resolution (WireGuard IPs)
│   │   │   ├── nix.nix              # Flakes, settings
│   │   │   ├── packages.nix         # Base CLI tools
│   │   │   ├── shell.nix            # Zsh + Oh-My-Zsh
│   │   │   └── users.nix            # User definitions
│   │   │
│   │   └── optional/                # Opt-in modules
│   │       ├── desktop/             # Niri, audio, fonts, apps
│   │       ├── gaming/              # Steam, GameMode, Vulkan
│   │       ├── hardware/            # AMD, Bluetooth, Framework
│   │       ├── networking/          # Firewall, NordVPN, SSH, WiFi, WireGuard, Syncthing, sops
│   │       ├── power/               # Performance, portable, hibernate
│   │       ├── security/            # LUKS/FIDO2, YubiKey, PAM U2F, sudo
│   │       └── storage/             # ZFS maintenance (scrub, snapshots, logrotate)
│   │
│   ├── workstation/                 # Gaming workstation
│   ├── laptop/                      # Framework 13 laptop
│   ├── server/                      # Home server
│
├── home/
│   ├── oat/                         # Home Manager entry point
│   └── common/optional/             # HM modules
│       ├── desktop/                 # Niri, Waybar, Fuzzel, Mako, etc.
│       ├── security/                # YubiKey user-level config
│       ├── theme.nix                # Catppuccin Macchiato
│       └── user-packages.nix        # User applications
│
└── docs/
    ├── audit/                       # System audit framework
    └── NORDVPN-SETUP.md             # VPN guide
```

## Secrets

Two layers of secrets management:

- **git-crypt** (build-time): `secrets/network.nix` — IPs, public keys, Syncthing device IDs. Encrypted in git, plaintext in the working tree. Used by Nix at evaluation time.
- **sops-nix** (runtime): `secrets/secrets.yaml` — WireGuard private keys. Encrypted in git via age, decrypted to `/run/secrets/` at system activation. Age keys are derived from each host's SSH host key.

### For repo contributors (using your own lab)

No git-crypt or sops key needed. Copy the templates and fill in your own values:

```bash
cp secrets/network.nix.example secrets/network.nix
# Edit secrets/network.nix with your IPs, public keys, and device IDs
```

For sops secrets, generate your own `.sops.yaml` with your hosts' age keys:

```bash
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

Then run `bash secrets/init-sops.sh` to collect and encrypt WireGuard private keys.

### For existing lab hosts

The git-crypt symmetric key is synced via Syncthing to `~/.config/git-crypt/nixos-lab.key` on all hosts. sops-nix uses SSH host keys automatically — no extra key distribution needed.

```bash
# Unlock git-crypt after a fresh clone
git-crypt unlock ~/.config/git-crypt/nixos-lab.key

# Edit sops secrets
nix-shell -p sops age ssh-to-age --run 'sops secrets/secrets.yaml'
```

### Committing changes to encrypted files

git-crypt must be in PATH when staging encrypted files:

```bash
nix-shell -p git-crypt --run 'git add -A && git commit -m "message"'
```

## System Management

```bash
# Rebuild current host
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)

# Deploy to all hosts (rebuild local, push, rebuild remotes via WireGuard SSH)
bash /etc/nixos/deploy.sh all

# Deploy to a specific remote host
bash /etc/nixos/deploy.sh server-nixos

# Preview changes
sudo nixos-rebuild dry-activate --flake /etc/nixos#$(hostname)

# Update flake inputs
sudo nix flake update /etc/nixos

# Garbage collect
sudo nix-collect-garbage --delete-older-than 30d
```

## Design Decisions

- **ZFS on LUKS** (not ZFS native encryption): enables FIDO2 unlock via systemd-cryptenroll, full-pool encryption including metadata
- **Single flake, multi-host**: shared modules reduce duplication; host-specific config via imports and `mkForce` overrides
- **Stable + unstable overlay**: `nixpkgs-25.11` base with `pkgs.unstable.<pkg>` for select packages
- **Filesystem-agnostic modules**: device paths and UUIDs live exclusively in `hardware-configuration.nix` (generated per-host by the installer)
- **Niri compositor**: scrollable tiling Wayland on all desktop hosts
- **Catppuccin Macchiato**: system-wide theming via Home Manager
- **WireGuard-only SSH**: `openFirewall = false` on SSH/Mosh services, port 22 opened only on `wg0` interface — no LAN SSH exposure
- **Two-layer secrets**: git-crypt for build-time values (IPs, public keys), sops-nix for runtime secrets (private keys) — different trust boundaries, appropriate tooling for each

## Networking

IPs and keys are in `secrets/network.nix`. The network topology:

- **WireGuard mesh** (`wg0`): encrypted full-mesh between all hosts. All SSH and NFS access is restricted to this mesh.

| Host | WireGuard IP |
|------|-------------|
| `workstation-nixos` | 10.100.0.1 |
| `server-nixos` | 10.100.0.2 |
| `laptop-nixos` | 10.100.0.3 |
- **NordVPN** (`wgnord`): outbound VPN via wgnord on workstation-nixos and laptop-nixos
- **Syncthing**: file sync across all hosts (LAN-only, no relays). Syncs `~/.claude/` and `~/.config/git-crypt/`
- **NFS**: server exports `/storage` to WireGuard subnet (encrypted in transit)

## Security

- LUKS2 with argon2id key derivation
- YubiKey FIDO2 for disk unlock (optional second factor)
- PAM U2F for sudo/login
- SSH restricted to WireGuard mesh: `openFirewall = false`, `ListenAddress` bound to each host's WireGuard IP, fail2ban on all hosts
- Firewall enabled on all hosts; admin services (SSH, Mosh, Ollama, AdGuard UI) restricted to `wg0` interface
- git-crypt for build-time secrets (network config), sops-nix for runtime secrets (private keys)
- Kernel hardening with loose rp_filter for WireGuard compatibility
- NordVPN via WireGuard (wgnord)

## License

Personal configuration repository. Reference or adapt freely.
