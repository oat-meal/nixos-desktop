# NixOS Lab

Multi-host NixOS infrastructure managed as a single Nix Flake. Declarative configurations for a personal computing environment with full-disk encryption (LUKS2 + ZFS) across all hosts.

## Hosts

| Host | Hardware | Storage | Status |
|------|----------|---------|--------|
| `workstation-nixos` | Ryzen 9950X, 64GB RAM, AMD GPU | ZFS on LUKS2 | Active |
| `laptop-nixos` | Framework 13, Ryzen, 32GB RAM | ZFS on LUKS2 | Active |
| `server-nixos` | Framework Server (5U rack) | ZFS on LUKS2 | Active |

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
│   │   │   ├── networking.nix       # NetworkManager
│   │   │   ├── nix.nix              # Flakes, settings
│   │   │   ├── packages.nix         # Base CLI tools
│   │   │   ├── shell.nix            # Zsh + Oh-My-Zsh
│   │   │   └── users.nix            # User definitions
│   │   │
│   │   └── optional/                # Opt-in modules
│   │       ├── desktop/             # Niri, audio, fonts, apps
│   │       ├── gaming/              # Steam, GameMode, Vulkan
│   │       ├── hardware/            # AMD, Bluetooth, Framework
│   │       ├── networking/          # Firewall, NordVPN, WiFi, WireGuard
│   │       ├── power/               # Performance, portable, hibernate
│   │       └── security/            # LUKS/FIDO2, YubiKey, PAM U2F
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

Network configuration (IPs, public keys, device IDs) is stored in `secrets/network.nix`, encrypted in git via **git-crypt**. A template with placeholder values is at `secrets/network.nix.example`.

After cloning the repo on a new host:

```bash
# Unlock with a GPG key that has been added to git-crypt
git-crypt unlock

# Or for first-time setup on a new host, export and import the symmetric key
# From an unlocked host:  git-crypt export-key /tmp/git-crypt-key
# On the new host:        git-crypt unlock /tmp/git-crypt-key
```

## System Management

```bash
# Rebuild current host
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)

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

## Networking

| | LAN | WireGuard Mesh |
|---|---|---|
| Subnet | <lan-subnet> | 10.100.0.0/24 |
| `workstation-nixos` | <lan-ip> | 10.100.0.1 |
| `server-nixos` | <server-lan-ip> | 10.100.0.2 |
| `laptop-nixos` | <laptop-lan-ip> | 10.100.0.3 |

- **WireGuard mesh** (`wg0`, port 51821): encrypted connectivity between all hosts
- **NordVPN** (`wgnord`, port 51820): outbound VPN via wgnord on workstation-nixos and laptop-nixos
- **Syncthing**: file sync across all hosts (LAN-only, no relays)
- **NFS**: server exports `/storage` to LAN

## Security

- LUKS2 with argon2id key derivation
- YubiKey FIDO2 for disk unlock (optional second factor)
- PAM U2F for sudo/login
- Firewall enabled on all hosts
- NordVPN via WireGuard (wgnord)
- Zen Browser as sole browser

## License

Personal configuration repository. Reference or adapt freely.
