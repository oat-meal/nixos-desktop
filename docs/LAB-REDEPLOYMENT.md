# NixOS Lab Redeployment Plan

## Overview

Full lab redeployment: migrate all hosts to ZFS, establish secrets management with YubiKey, automated backups, WireGuard mesh networking, and deployment tooling.

**Hosts (existing hardware):**

| Host | Hardware | Role | Order |
|------|----------|------|-------|
| `laptop-nixos` | Framework 13 (Ryzen, 8-core) | Portable | 1st (pilot) |
| `workstation-nixos` | Ryzen 9950X, 64GB, RX 9070 XT | Gaming/daily driver | 2nd |
| `server-nixos` | Framework Server (Ryzen AI Max+ 395, 128GB unified) | Home server | 3rd |
| `relay-nixos` | VPS (optional) | Offsite backup / fallback relay | Optional |

**Rack:** StarTech RK12WALLOA (19-inch, 12U, wall-mount, 12-20" adjustable depth) — mounted in open closet

**Storage strategy:** Server uses internal 2x 1TB NVMe (ZFS mirror for rpool) + USB-C DAS in the rack for bulk storage (tank pool). No separate NAS computer needed — the Framework Server handles all compute.

Laptop goes first — lowest risk, fastest to reinstall, validates the full workflow before touching the workstation.

---

## Pre-requisite: Custom Installer USB

**Goal:** Build a NixOS installer USB with Claude Code, ZFS/LUKS tooling, YubiKey support, and an interactive install script that deploys any host with minimal interaction.

### USB Layout

```
/dev/sdX (58GB SanDisk Ultra USB 3.0)
├── Partition 1: NixOS ISO (bootable, ~3-4GB)
│   └── Custom ISO with all tools, Claude Code, install script
└── Partition 2: Persistent data (ext4, remaining space)
    └── nixos-lab/          ← git clone of flake repo
        ├── flake.nix       ← local copy, refreshable from GitHub
        ├── installer/
        │   └── install.sh  ← main install script
        └── ...
```

### Installer Config

Create `installer/default.nix`:
```nix
{ pkgs, lib, ... }:

{
  imports = [
    "${pkgs.path}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # ZFS + LUKS support
  boot.supportedFilesystems = [ "zfs" ];

  # Networking for Claude Code auth
  networking = {
    wireless.enable = lib.mkForce false;
    networkmanager.enable = true;
  };

  # All firmware (WiFi 7 ath12k, etc.)
  hardware.enableAllFirmware = true;

  environment.systemPackages = with pkgs; [
    # Claude assistant
    unstable.claude-code

    # ZFS + LUKS partitioning workflow
    parted
    gptfdisk
    dosfstools
    cryptsetup
    tpm2-tss        # systemd-cryptenroll FIDO2 support

    # Essentials
    git
    neovim
    tmux            # terminal multiplexer (useful during install)
    htop
    ripgrep
    wget
    curl

    # Networking
    networkmanagerapplet
    iw

    # YubiKey + agenix (for key operations during install)
    yubikey-manager
    libfido2
    gnupg
    pinentry-curses
    age
    age-plugin-yubikey
    pam_u2f
  ];

  programs.zsh.enable = true;
  users.users.nixos.shell = pkgs.zsh;

  # Smart card daemon for YubiKey
  services.pcscd.enable = true;

  # SSH server for headless install option
  services.openssh.enable = true;

  # Larger console font (Framework laptop readability)
  console.font = "ter-v24n";
  console.packages = [ pkgs.terminus_font ];

  # Place Claude context and install script where they're discoverable on boot
  environment.etc."claude/CLAUDE.md".source = ./claude-config/CLAUDE.md;
  environment.etc."claude/LAB-REDEPLOYMENT.md".source = ./claude-config/LAB-REDEPLOYMENT.md;

  # Auto-mount persistent USB partition and set up Claude context
  system.activationScripts.installer-setup = ''
    mkdir -p /home/nixos/.claude

    # Link Claude config
    ln -sf /etc/claude/CLAUDE.md /home/nixos/.claude/CLAUDE.md

    # Copy plan to home for easy reference
    cp /etc/claude/LAB-REDEPLOYMENT.md /home/nixos/LAB-REDEPLOYMENT.md 2>/dev/null || true

    chown -R nixos:users /home/nixos/.claude /home/nixos/LAB-REDEPLOYMENT.md 2>/dev/null || true

    # Create convenience aliases
    cat > /home/nixos/.zshrc.local <<'ALIASES'
    alias install-nixos='sudo /etc/nixos-installer/install.sh'
    alias refresh-flake='sudo /etc/nixos-installer/refresh-flake.sh'
    ALIASES
    chown nixos:users /home/nixos/.zshrc.local
  '';

  # Include the install scripts
  environment.etc."nixos-installer/install.sh" = {
    source = ./install.sh;
    mode = "0755";
  };
  environment.etc."nixos-installer/refresh-flake.sh" = {
    source = ./refresh-flake.sh;
    mode = "0755";
  };
}
```

### Add ISO output to flake.nix
```nix
# In outputs, alongside nixosConfigurations:
packages.x86_64-linux.installer = (nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./installer
    { nixpkgs.overlays = [ unstableOverlay ]; }
  ];
}).config.system.build.isoImage;
```

### Build and flash
```bash
# Build the ISO
nix build /etc/nixos#installer

# Partition the USB: ISO partition + persistent data
# (the install script handles this, or manually:)
parted /dev/sdX -- mklabel gpt
parted /dev/sdX -- mkpart primary fat32 1MiB 4GiB    # ISO boot
parted /dev/sdX -- mkpart primary ext4 4GiB 100%      # persistent data

# Flash ISO to partition 1
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Format and populate persistent partition
mkfs.ext4 -L NIXOS-DATA /dev/sdX2
mount /dev/sdX2 /mnt/usb
git clone https://github.com/oat-meal/nixos-lab.git /mnt/usb/nixos-lab
umount /mnt/usb
```

### Usage

```bash
# Boot the USB
# Connect to wifi (if needed)
nmcli device wifi connect <SSID> password <pass>

# Run the interactive installer (select host, confirm disks, tap YubiKey)
install-nixos

# Or refresh the local flake copy from GitHub first
refresh-flake

# Claude is available with full lab context
claude
# "I'm installing laptop-nixos, help me with Phase 2."

# YubiKey tools ready for Phase 0
ykman info
```

### Install Flow (minimal interaction)
```
Boot USB → menu appears:

╔════════════════════════════════════════════╗
║     NixOS Lab Installer — ZFS/LUKS        ║
╚════════════════════════════════════════════╝

1) laptop-nixos      — Framework 13 (1x NVMe, hibernate)
2) workstation-nixos  — Ryzen 9950X (1x NVMe + storage mirror)
3) server-nixos      — Framework Server (2x NVMe mirror)
r) Refresh flake from GitHub
q) Exit to shell

Select host → auto-detect disks → confirm →
set LUKS passphrase → enroll YubiKey(s) →
[automated: partition, LUKS, ZFS, mount, nixos-install] →
post-install checklist
```

### Deliverables
- [ ] `installer/default.nix` created
- [ ] `installer/install.sh` — interactive install script
- [ ] `installer/refresh-flake.sh` — pull latest flake from GitHub
- [ ] `installer/claude-config/` with CLAUDE.md and LAB-REDEPLOYMENT.md
- [ ] ISO output added to flake.nix
- [ ] USB built: ISO partition + persistent data partition
- [ ] Local flake repo on USB, refreshable
- [ ] Verified: boot, select host, full automated install with LUKS + ZFS
- [ ] Verified: YubiKey FIDO2 enrollment during install
- [ ] Verified: Claude available with full lab context

---

## Phase 0: YubiKey Provisioning

**Goal:** Set up all 3 YubiKeys as the identity foundation for the entire lab. Any key can unlock any host, decrypt any secret, and authenticate anywhere.

### Prerequisites
- 3x YubiKey 5 series
- Airgapped machine or NixOS live USB for GPG key generation

### Key Roles

| YubiKey | Role | Location |
|---------|------|----------|
| #1 | Primary — daily carry | Keychain |
| #2 | Backup — daily alternate | Desk/bag |
| #3 | Recovery — cold storage | Safe/offsite |

All 3 keys receive identical GPG subkeys, FIDO2 credentials, and are enrolled in LUKS/PAM on every host.

### Steps

#### 0.1 Generate GPG Master Key (airgapped)
```bash
# Boot NixOS installer USB (disconnect network)
gpg --full-generate-key
# RSA 4096, no expiry (or set expiry and extend later)

# Create subkeys: Sign, Encrypt, Authenticate
gpg --edit-key <KEY_ID>
# addkey (RSA sign), addkey (RSA encrypt), addkey (RSA auth)

# CRITICAL: backup master key BEFORE keytocard (keytocard is destructive)
gpg --export-secret-keys --armor <KEY_ID> > master-key.asc
gpg --export-secret-subkeys --armor <KEY_ID> > subkeys-backup.asc
gpg --export --armor <KEY_ID> > oat-pub.asc
```

#### 0.2 Move Subkeys to YubiKey #1 (primary)
```bash
gpg --edit-key <KEY_ID>
# keytocard for each subkey (sig -> slot 1, enc -> slot 2, auth -> slot 3)
# This MOVES (not copies) the subkeys — they're now only on the card
```

#### 0.3 Clone Subkeys to YubiKey #2
```bash
# keytocard destroyed the local copy — re-import from backup
gpg --delete-secret-keys <KEY_ID>
gpg --import master-key.asc

gpg --edit-key <KEY_ID>
# keytocard for each subkey to YubiKey #2
```

#### 0.4 Clone Subkeys to YubiKey #3
```bash
# Repeat: re-import and keytocard
gpg --delete-secret-keys <KEY_ID>
gpg --import master-key.asc

gpg --edit-key <KEY_ID>
# keytocard for each subkey to YubiKey #3
```

#### 0.5 Configure PINs and Touch Policy (all 3 keys)
```bash
# Repeat for each YubiKey:
ykman openpgp access change-pin
ykman openpgp access change-admin-pin
ykman openpgp keys set-touch sig cached
ykman openpgp keys set-touch enc cached
ykman openpgp keys set-touch aut cached
ykman fido access change-pin
```

#### 0.6 Generate FIDO2/SSH Resident Keys (all 3 keys)
```bash
# Insert YubiKey #1
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "oat@nixos-lab-key1"
# Insert YubiKey #2
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "oat@nixos-lab-key2"
# Insert YubiKey #3
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "oat@nixos-lab-key3"
```

#### 0.7 Generate age Identities (all 3 keys)
```bash
# Insert each YubiKey and run:
age-plugin-yubikey
# Records the age1yubikey1... public key for each
# Save all 3 public keys — needed for secrets.nix
```

#### 0.8 Register FIDO2 for PAM (all 3 keys)
```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys          # key #1
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys       # key #2
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys       # key #3
```

#### 0.9 Store Backups
```bash
# Store on encrypted USB, keep offline/offsite:
# - master-key.asc (GPG master private key)
# - subkeys-backup.asc
# - oat-pub.asc
# - FIDO2 resident key backups (ssh-keygen -K)
# - age public keys for all 3 YubiKeys
```

#### 0.10 Publish Public Keys
```bash
gpg --send-keys <KEY_ID>
gh ssh-key add id_ed25519_sk_key1.pub --title "YubiKey #1"
gh ssh-key add id_ed25519_sk_key2.pub --title "YubiKey #2"
gh ssh-key add id_ed25519_sk_key3.pub --title "YubiKey #3"
```

### Deliverables
- [ ] All 3 YubiKeys provisioned with identical GPG subkeys
- [ ] GPG master key backed up offline (encrypted USB)
- [ ] FIDO2 SSH resident keys on all 3 YubiKeys
- [ ] age identities generated for all 3 YubiKeys
- [ ] PAM U2F registered for all 3 keys
- [ ] Public keys published (GitHub, keyserver)
- [ ] Default PINs changed, touch policy set on all 3

---

## Phase 1: Secrets Management (agenix)

**Goal:** Encrypted secrets in-repo, decrypted at activation time.

### 1.1 Add agenix to flake.nix
```nix
inputs.agenix = {
  url = "github:ryantm/agenix";
  inputs.nixpkgs.follows = "nixpkgs";
};

# Add to mkSystem modules
modules = [ agenix.nixosModules.default ];
```

### 1.2 Create secrets structure
```
secrets/
  secrets.nix              # public keys + per-host access
  wireguard/
    laptop.age
    workstation.age
    server.age
    preshared.age
  nordvpn/
    private-key.age
```

### 1.3 Define secrets.nix
```nix
let
  # YubiKey age identities — any key can decrypt any secret
  yubikey1 = "age1yubikey1qg...";  # primary (daily carry)
  yubikey2 = "age1yubikey1qx...";  # backup
  yubikey3 = "age1yubikey1qz...";  # recovery (cold storage)
  oat = [ yubikey1 yubikey2 yubikey3 ];

  # Host SSH public keys (from /etc/ssh/ssh_host_ed25519_key.pub)
  laptop = "ssh-ed25519 AAAA...";
  workstation = "ssh-ed25519 AAAA...";
  server = "ssh-ed25519 AAAA...";

  allHosts = [ laptop workstation server ];
  desktopHosts = [ laptop workstation ];
in {
  "wireguard/laptop.age".publicKeys = oat ++ [ laptop ];
  "wireguard/workstation.age".publicKeys = oat ++ [ workstation ];
  "wireguard/server.age".publicKeys = oat ++ [ server ];
  "wireguard/preshared.age".publicKeys = oat ++ allHosts;
  "nordvpn/private-key.age".publicKeys = oat ++ desktopHosts;
}
```

### 1.4 Encrypt secrets
```bash
cd /etc/nixos
wg genkey | tee /tmp/wg-laptop | wg pubkey > /tmp/wg-laptop.pub
agenix -e secrets/wireguard/laptop.age
# Repeat per host
```

### Deliverables
- [ ] agenix in flake inputs and mkSystem
- [ ] secrets/secrets.nix with all host public keys
- [ ] WireGuard keys generated and encrypted for all hosts
- [ ] NordVPN key migrated from plaintext to agenix

---

## Phase 2: ZFS Migration — Laptop (pilot)

**Goal:** Reinstall laptop-nixos on ZFS, validate the full stack.

### 2.1 Backup
```bash
sudo btrfs subvolume snapshot -r /home /home/.snapshot-pre-zfs
rsync -avP /home/oat/ /mnt/backup/laptop-home/
```

### 2.2 Disk Layout
```
/dev/nvme0n1
├── p1: EFI System Partition (512MB, FAT32)
└── p2: LUKS2 container
        ├── Unlock: YubiKey FIDO2 (tap to unlock at boot)
        ├── Unlock: Passphrase (fallback)
        └── /dev/mapper/cryptroot → ZFS rpool
```

### 2.3 ZFS Pool Layout
```
rpool (on /dev/mapper/cryptroot — LUKS2 encrypted)
  rpool/ROOT/nixos         mountpoint=/           compression=zstd
  rpool/home               mountpoint=/home       compression=zstd
  rpool/nix                mountpoint=/nix         compression=zstd, atime=off
  rpool/log                mountpoint=/var/log     compression=zstd

# Hibernate support: zvol instead of Btrfs swapfile
rpool/swap                 volsize=32G, compression=zle, sync=always
```

### 2.4 Install

The install script (`installer/install.sh`) automates this, but the manual steps are:

```bash
# Boot NixOS installer USB
# Partition: EFI (512MB) + LUKS remainder
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

mkfs.fat -F32 /dev/nvme0n1p1

# Create LUKS2 container with passphrase
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Enroll YubiKey FIDO2 (all 3 keys)
systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto  # key #1
systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto  # key #2
systemd-cryptenroll /dev/nvme0n1p2 --fido2-device=auto  # key #3

# Create ZFS pool on LUKS device
zpool create -o ashift=12 -O mountpoint=none -O acltype=posixacl \
  -O xattr=sa -O compression=zstd -O normalization=formD \
  rpool /dev/mapper/cryptroot

# Create datasets
zfs create -o mountpoint=legacy rpool/ROOT
zfs create -o mountpoint=legacy rpool/ROOT/nixos
zfs create -o mountpoint=legacy rpool/home
zfs create -o mountpoint=legacy -o atime=off rpool/nix
zfs create -o mountpoint=legacy rpool/log
zfs create -V 32G -b 4096 -o compression=zle -o sync=always rpool/swap

# Mount
mount -t zfs rpool/ROOT/nixos /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -t zfs rpool/home /mnt/home
mount -t zfs rpool/nix /mnt/nix
mount -t zfs rpool/log /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot

mkswap /dev/zvol/rpool/swap
swapon /dev/zvol/rpool/swap

# Generate config and install
nixos-generate-config --root /mnt
# Copy flake, edit hardware-configuration.nix
nixos-install --flake /mnt/etc/nixos#laptop-nixos
```

### 2.5 Common ZFS + LUKS Module

Create `hosts/common/optional/storage/zfs.nix`:
```nix
{ config, lib, ... }:
{
  boot.supportedFilesystems = [ "zfs" ];
  services.zfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };
  services.zfs.trim.enable = true;
}
```

Create `hosts/common/optional/storage/luks.nix`:
```nix
{ config, lib, ... }:
{
  # LUKS2 with FIDO2 (YubiKey) unlock at boot
  # The specific device UUID is set in each host's hardware-configuration.nix
  boot.initrd.luks.fido2Support = true;
  boot.initrd.systemd.enable = true;  # systemd in initrd for FIDO2
}
```

### 2.6 Laptop Config Changes

Update `hosts/laptop/default.nix`:
```nix
imports = [
  # ...existing imports...
  ../common/optional/storage/zfs.nix
  ../common/optional/storage/luks.nix
];

# Required: unique per host
networking.hostId = "XXXXXXXX";  # head -c 8 /etc/machine-id
```

The generated `hardware-configuration.nix` will include:
```nix
boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-uuid/<LUKS-UUID>";
  cryptTabExtraOpts = [ "fido2-device=auto" ];
};
```

Update `hosts/common/optional/power/hibernate.nix`:
```nix
# Replace Btrfs swapfile with ZFS zvol
swapDevices = [{ device = "/dev/zvol/rpool/swap"; }];
boot.resumeDevice = "/dev/zvol/rpool/swap";
# Remove resume_offset (not needed for zvol)
```

Update `hosts/common/core/packages.nix`:
```nix
# Replace btrfs-progs with zfs tools (or keep both during transition)
```

### 2.6 Validate
- [ ] Boot succeeds
- [ ] ZFS pools import automatically
- [ ] Hibernate/resume works via zvol
- [ ] agenix secrets decrypt at activation
- [ ] YubiKey GPG/SSH/FIDO2 all working
- [ ] NordVPN connects using agenix-managed key
- [ ] Home data restored from backup

### Deliverables
- [ ] Laptop fully operational on ZFS
- [ ] hibernate.nix updated for zvol
- [ ] storage/zfs.nix common module created
- [ ] hardware-configuration.nix regenerated
- [ ] Process documented for workstation/server repeats

---

## Phase 3: ZFS Migration — Workstation

**Goal:** Reinstall workstation-nixos on ZFS using validated laptop workflow.

### 3.1 Backup
```bash
rsync -avP /home/oat/ /mnt/backup/workstation-home/
rsync -avP /storage/ /mnt/backup/workstation-storage/
```

### 3.2 Disk Layout
```
/dev/nvme0n1 (OS drive)
├── p1: EFI System Partition (512MB, FAT32)
└── p2: LUKS2 container → /dev/mapper/cryptroot → ZFS rpool

/dev/sdX + /dev/sdY (storage drives)
├── LUKS2 container each → /dev/mapper/cryptstorage1, cryptstorage2
└── ZFS storage mirror on LUKS devices
```

### 3.3 ZFS Pool Layout
```
rpool (on /dev/mapper/cryptroot — LUKS2 encrypted)
  rpool/ROOT/nixos         mountpoint=/           compression=zstd
  rpool/home               mountpoint=/home       compression=zstd
  rpool/nix                mountpoint=/nix         compression=zstd, atime=off
  rpool/log                mountpoint=/var/log     compression=zstd

# Storage pool (existing RAID1 drives, migrate Btrfs -> ZFS)
storage (mirror on /dev/mapper/cryptstorage{1,2} — LUKS2 encrypted)
  storage/data             mountpoint=/storage    compression=zstd, recordsize=1M
```

### 3.4 Workstation-Specific
```nix
networking.hostId = "YYYYYYYY";

# ARC cache cap — leave room for gaming (16GB of 64GB)
boot.kernelParams = [
  # ...existing gaming params...
  "zfs.zfs_arc_max=17179869184"
];

# Import storage pool
boot.zfs.extraPools = [ "storage" ];

# LUKS devices (in hardware-configuration.nix)
boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-uuid/<LUKS-UUID>";
  cryptTabExtraOpts = [ "fido2-device=auto" ];
};
boot.initrd.luks.devices."cryptstorage1" = {
  device = "/dev/disk/by-uuid/<LUKS-UUID>";
  cryptTabExtraOpts = [ "fido2-device=auto" ];
};
boot.initrd.luks.devices."cryptstorage2" = {
  device = "/dev/disk/by-uuid/<LUKS-UUID>";
  cryptTabExtraOpts = [ "fido2-device=auto" ];
};
```

### 3.4 Validate
- [ ] Boot succeeds, gaming performance unaffected
- [ ] /storage pool imported from mirror drives
- [ ] ARC not competing with games (monitor with `arc_summary`)
- [ ] All existing workflows intact (Steam, GameMode, etc.)

---

## Phase 4: Server Setup (Framework Server)

**Goal:** Deploy server-nixos on the Framework Server with internal ZFS + USB-C DAS for bulk storage.

### 4.1 Hardware Overview

| Component | Detail |
|-----------|--------|
| CPU | AMD Ryzen AI Max+ 395 (16C/32T, Zen 5) |
| RAM | 128GB unified (on-package, not expandable) |
| GPU | Integrated Radeon 8060S (40 CUs, RDNA 3.5) — hardware transcode |
| Internal storage | 2x 1TB SanDisk SN7100 NVMe (M.2 PCIe 4.0) |
| Cooling | Noctua NF-A12x25 |
| Connectivity | USB-C, Ethernet expansion card |
| TDP | ~120W max, ~30-50W idle server loads |

### 4.2 DAS (Direct Attached Storage)

The Framework Server's internal 2x 1TB NVMe become the ZFS boot mirror (`rpool`).
Bulk storage lives on a USB-C DAS mounted in the rack.

**DAS options (19-inch rack):**

| Option | Drives | Interface | Form Factor | Notes |
|--------|--------|-----------|-------------|-------|
| ORICO/Sabrent 4-bay 2.5" USB-C on 1U shelf | 4x 2.5" SATA SSD/HDD | USB-C 10Gbps | 1U shelf | Simple, proven |
| OWC Express 4M2 on 1U shelf | 4x M.2 NVMe | USB4 40Gbps | 1U shelf | Fastest, all-NVMe |
| ICY DOCK ToughArmor MB720M2K-B (19" rack) | 4x M.2 NVMe | USB-C/U.2 | 1U native | Purpose-built rack mount |

**Recommendation:** Start with a **4-bay 2.5" USB-C SATA enclosure** (ORICO or Sabrent, ~$40-60) on a 1U cantilever shelf (~$20). This gives you 4x 2.5" drives for the ZFS `tank` pool at 10Gbps — plenty for NFS, Jellyfin, and backups. Upgrade to NVMe later if needed.

### 4.3 Disk Layout
```
/dev/nvme0n1 + /dev/nvme1n1 (2x internal NVMe)
├── p1: EFI System Partition (512MB, FAT32) — nvme0n1 only
└── p2: LUKS2 container each
        ├── /dev/mapper/cryptroot0, /dev/mapper/cryptroot1
        └── ZFS rpool mirror on both LUKS devices

USB-C DAS drives
├── LUKS2 container each (same YubiKey enrollment)
└── ZFS tank mirror/raidz1 on LUKS devices
```

### 4.4 ZFS Pool Layout
```
# Internal NVMe (ZFS mirror on LUKS2 — OS, home, nix)
rpool (mirror: /dev/mapper/cryptroot0 + /dev/mapper/cryptroot1)
  rpool/ROOT/nixos         mountpoint=/           compression=zstd
  rpool/home               mountpoint=/home       compression=zstd
  rpool/nix                mountpoint=/nix         compression=zstd, atime=off
  rpool/log                mountpoint=/var/log     compression=zstd

# USB-C DAS (ZFS mirror or raidz1 on LUKS2)
tank (mirror or raidz1 on /dev/mapper/crypttank{1,2,...})
  tank/media               recordsize=1M, compression=zstd
  tank/backups             compression=zstd
  tank/share               compression=zstd
  tank/containers          compression=zstd
```

**Important:** Use ZFS disk-by-id paths for the USB DAS to avoid device name shuffling:
```bash
# Create LUKS on each DAS drive, then ZFS on the LUKS devices
cryptsetup luksFormat --type luks2 /dev/disk/by-id/usb-VENDOR-SERIAL1-part1
cryptsetup luksFormat --type luks2 /dev/disk/by-id/usb-VENDOR-SERIAL2-part1
# Enroll YubiKeys, then:
zpool create tank mirror /dev/mapper/crypttank1 /dev/mapper/crypttank2
```

### 4.5 Server Config
```nix
# hosts/server/default.nix
networking.hostId = "ZZZZZZZZ";

# Import USB DAS pool
boot.zfs.extraPools = [ "tank" ];

# ARC can be generous — 128GB unified, no competing GPU VRAM allocation
# Let ZFS use up to 32GB for ARC (server workload, not gaming)
boot.kernelParams = [ "zfs.zfs_arc_max=34359738368" ];

# Jellyfin — hardware transcode via integrated Radeon 8060S
services.jellyfin = {
  enable = true;
  openFirewall = false;
};
# VAAPI for AMD hardware transcode
hardware.graphics.enable = true;

# NFS (Linux clients over WireGuard)
services.nfs.server = {
  enable = true;
  exports = ''
    /tank/share  10.100.0.0/24(rw,sync,no_subtree_check,no_root_squash)
    /tank/media  10.100.0.0/24(ro,sync,no_subtree_check)
  '';
};

# Samba
services.samba = {
  enable = true;
  settings = {
    global = {
      workgroup = "LAB";
      "server string" = "server-nixos";
      security = "user";
    };
    share = {
      path = "/tank/share";
      browseable = true;
      "read only" = false;
      "valid users" = "oat";
    };
    media = {
      path = "/tank/media";
      browseable = true;
      "read only" = true;
      "valid users" = "oat";
    };
  };
};

# Podman
virtualisation.podman = {
  enable = true;
  dockerCompat = true;
  defaultNetwork.settings.dns_enabled = true;
};

virtualisation.oci-containers.backend = "podman";
virtualisation.oci-containers.containers = {
  home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable";
    volumes = [ "/tank/containers/hass:/config" ];
    extraOptions = [ "--network=host" ];
  };
};

# AdGuard Home — network-wide DNS ad-blocking
# Turris DHCP hands out this server's IP as DNS
services.adguardhome = {
  enable = true;
  mutableSettings = false;
  settings = {
    dns = {
      bind_hosts = [ "0.0.0.0" ];
      port = 53;
      upstream_dns = [
        "https://dns.cloudflare.com/dns-query"
        "https://dns.google/dns-query"
      ];
      bootstrap_dns = [ "1.1.1.1" "8.8.8.8" ];
    };
    filtering.enabled = true;
  };
};

# Firewall: services on LAN + wg0
networking.firewall = {
  allowedTCPPorts = [ 53 3000 ];  # DNS + AdGuard Home web UI
  allowedUDPPorts = [ 53 ];        # DNS
  interfaces."wg0" = {
    allowedTCPPorts = [ 2049 139 445 8096 ];
    allowedUDPPorts = [ 137 138 ];
  };
};
```

### 4.6 Network Architecture

**Router:** Turris Omnia NG (OpenWrt, WiFi 7 tri-band, 2x 10GbE SFP+, rack-mount)
**Switch:** Managed 8-port 2.5GbE + 10G SFP+ uplink (port mirroring capable)

```
ISP Fiber ONT
      │
      │ SFP+ (10G) or Ethernet
      ▼
Turris Omnia NG (OpenWrt — router/firewall/DHCP/WiFi 7 AP)
      │
      │ SFP+ (10G) trunk to switch
      ▼
Managed 2.5GbE Switch (L2, port mirroring)
      │
      ├── Port 1: Framework Server — data (<lan-ip>)
      │             ├── AdGuard Home (DNS, port 53)
      │             ├── NFS/Samba (file sharing)
      │             ├── Jellyfin (media, port 8096)
      │             ├── Podman containers
      │             └── WireGuard mesh peer
      │
      ├── Port 2: Framework Server — mirror port (IDS, Phase 8)
      ├── Port 3: Workstation (<lan-ip>)
      ├── Port 4: Laptop (when home, <lan-ip>)
      ├── Port 5-8: Available (IoT, future devices)
      └── SFP+: Uplink to Turris

Turris config (OpenWrt):
  - WAN: SFP+ to ISP ONT
  - LAN: SFP+ to managed switch
  - DHCP: hands out server IP (<lan-ip>) as DNS
  - Fallback DNS: 1.1.1.1, 8.8.8.8 (if server is down)
  - NAT/firewall: nftables (OpenWrt native)
  - WiFi 7 tri-band:
      2.4GHz SSID: IoT / appliances
      5GHz SSID: general devices
      6GHz SSID: high-speed / WiFi 7 devices
  - VLANs: optional (IoT isolation, guest network)
```

**Note:** Server needs a **second Ethernet interface** (USB-C to 2.5GbE adapter, ~$15) for the IDS mirror port in Phase 8. Not required until then.

### 4.7 Rack Layout

**Rack:** StarTech RK12WALLOA (19", 12U, wall-mount, adjustable 12-20" depth)
**Closet depth:** 24-25" — rack set to ~16-18" depth with clearance behind for airflow

**Framework Server dimensions:** 226 x 205 x 97mm (8.9" x 8.1" x 3.8") — sits on a 1U shelf, occupies 3U total height.

```
StarTech RK12WALLOA (19", 12U, wall-mounted in closet)
┌───────────────────────────────────┐
│ U12  1U  Brush cable mgmt panel   │
│ U11  1U  Turris Omnia NG (router/ │
│          firewall/WiFi 7 AP)       │
│ U10  1U  Managed 2.5GbE switch    │
│ U9   1U  1U PDU (power dist)      │
│ U8   1U  Blanking panel (vented)  │
│ U7   1U  1U shelf — DAS enclosure │
│ U6   1U  Blanking panel (vented)  │
│ U5   1U  ┐                        │
│ U4   1U  │ Framework Server       │
│ U3   1U  ┘ on 1U cantilever shelf │
│ U2   1U  ┐                        │
│ U1   1U  ┘ UPS (2U rack-mount)    │
└───────────────────────────────────┘
```

**Clean appearance accessories:**

| Item | Purpose | Price |
|------|---------|-------|
| 1U solid blanking panels | Spares for future layout changes | ~$5 ea |
| 1U vented blanking panels (x2) | Airflow gaps around server/DAS | ~$6 ea |
| 1U brush cable mgmt panel (x1) | Clean cable pass-through at top | ~$10 |
| 1U cantilever shelf (x2) | Mount server + DAS | ~$20 ea |

Every U is accounted for — no open gaps visible from the front.

### 4.8 E-Ink NOC Dashboard (optional)

Color e-paper display mounted in the rack showing live server metrics.

**Hardware:**

| Component | Spec | Price |
|-----------|------|-------|
| Pimoroni Inky Impression or Waveshare 7.3" ACeP | 800x480, 7-color | ~$65-75 |
| Raspberry Pi Zero 2W | Drives display, pulls images over WiFi | ~$15 |
| 1U blanking panel (modified) | Cutout for display, flush mount | ~$5-10 |

**Color mapping (7-color ACeP: black, white, red, green, blue, yellow, orange):**
- Green = healthy/online
- Red = critical/alert/degraded
- Yellow/Orange = warning/UPS on battery
- Blue = informational/connected
- Black/White = text, labels

**Server-side rendering (NixOS systemd timer):**
```nix
# Render dashboard to PNG, served via simple HTTP for Pi to fetch
systemd.services.noc-dashboard = {
  description = "Render NOC dashboard image";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.python3.withPackages (p: [ p.pillow p.requests ])}/bin/python /etc/nixos/scripts/noc-render.py";
  };
};
systemd.timers.noc-dashboard = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "*:0/2";  # every 2 minutes
    Persistent = true;
  };
};
```

**Dashboard layout:**
```
┌─────────────────────────────────────┐
│  ZFS Pools          WireGuard Mesh  │
│  ■ rpool  ONLINE    ● laptop        │
│  ■ tank   ONLINE    ● workstation   │
│  Containers         AdGuard Home    │
│  ■ hass   UP        847 queries     │
│  ■ jellyfin UP      12% blocked     │
│                                     │
│  CPU 8%  RAM 24%  UPS 100% ■■■■■■  │
│         server-nixos · 47d uptime   │
└─────────────────────────────────────┘
```

**Refresh:** Color ACeP takes ~15-30 seconds per update. With a 2-minute interval, the brief flash is acceptable. Display draws near-zero power between refreshes.

**Mount:** Replace one vented blanking panel with a modified panel (3D-printed or laser-cut acrylic) with a rectangular cutout. Display sits flush behind the panel.

### 4.9 UPS Integration

```nix
# NixOS UPS monitoring (apcupsd or NUT)
services.apcupsd = {
  enable = true;
  configText = ''
    UPSCABLE usb
    UPSTYPE usb
    DEVICE
    BATTERYLEVEL 15
    MINUTES 5
    TIMEOUT 0
  '';
};
# Graceful ZFS export on power loss
```

### 4.10 Validate
- [ ] NixOS boots on Framework Server
- [ ] rpool mirror (2x internal NVMe) healthy
- [ ] USB-C DAS detected, tank pool imports on boot
- [ ] tank pool survives USB reconnection / reboot
- [ ] Jellyfin hardware transcode working (VAAPI)
- [ ] NFS/Samba accessible from workstation
- [ ] Podman containers running from tank/containers
- [ ] AdGuard Home resolving DNS, ads blocked network-wide
- [ ] Turris Omnia NG routing, DHCP handing out server as DNS
- [ ] Turris fallback DNS works when server is down
- [ ] Managed switch ports assigned, uplink to Turris via SFP+
- [ ] UPS detected by apcupsd, graceful shutdown tested
- [ ] Rack fully populated — no open gaps, clean front appearance
- [ ] (Optional) E-ink NOC dashboard displaying live metrics

### Deliverables
- [ ] server-nixos installed on Framework Server
- [ ] DAS mounted in rack, tank pool created
- [ ] Turris Omnia NG configured as router/firewall/DHCP/WiFi 7 AP
- [ ] Managed switch configured (port assignments, SFP+ uplink)
- [ ] AdGuard Home running, network-wide ad-blocking
- [ ] ISP router replaced (Turris + server handle everything)
- [ ] NFS/Samba exporting share and media
- [ ] Jellyfin serving from tank/media with hardware transcode
- [ ] Home Assistant container running
- [ ] UPS monitoring and auto-shutdown configured
- [ ] Rack fully built with blanking/brush panels, clean cable management

---

## Phase 5: WireGuard Mesh Network

**Goal:** All hosts reachable over WireGuard, server as hub (public IP from ISP).

**ISP:** Municipal fiber typically provides a real public IP without CGNAT. Verify with `curl -4 ifconfig.me` and compare to Turris WAN IP. Request a static IP if available, or use DDNS if it rotates.

### Network Topology
```
                 Internet
                    |
              server-nixos (home, public IP or DDNS)
              10.100.0.1
              port 51820 forwarded via Turris
                /       \
     laptop              workstation
     10.100.0.20         10.100.0.10
     (roaming)           (home LAN)
```

### IP Allocation

| Host | WireGuard IP | Notes |
|------|-------------|-------|
| server-nixos | 10.100.0.1/24 | Hub, public endpoint |
| workstation-nixos | 10.100.0.10/24 | Home LAN (also direct) |
| laptop-nixos | 10.100.0.20/24 | Roaming, needs WG for remote access |

### Server (hub)
```nix
age.secrets.wg-server-key.file = ../../secrets/wireguard/server.age;
age.secrets.wg-psk.file = ../../secrets/wireguard/preshared.age;

networking.wireguard.interfaces.wg0 = {
  ips = [ "10.100.0.1/24" ];
  listenPort = 51820;
  privateKeyFile = config.age.secrets.wg-server-key.path;

  peers = [
    { publicKey = "<workstation-pub>"; allowedIPs = [ "10.100.0.10/32" ];
      presharedKeyFile = config.age.secrets.wg-psk.path; }
    { publicKey = "<laptop-pub>"; allowedIPs = [ "10.100.0.20/32" ];
      presharedKeyFile = config.age.secrets.wg-psk.path; }
  ];

  postUp = "iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT";
  postDown = "iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT";
};

boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
```

### Turris port forward
```
# OpenWrt firewall rule on Turris Omnia NG:
# Forward UDP 51820 from WAN -> <lan-ip> (server)
```

### DDNS (if IP is dynamic)
```nix
# Optional: update DDNS record when IP changes
services.ddclient = {
  enable = true;
  protocol = "duckdns";  # or cloudflare
  domains = [ "nixos-lab" ];
  passwordFile = config.age.secrets.ddns-token.path;
};
```

### Peers (laptop, workstation)
```nix
networking.wireguard.interfaces.wg0 = {
  ips = [ "10.100.0.XX/24" ];  # per host
  privateKeyFile = config.age.secrets.wg-key.path;
  peers = [{
    publicKey = "<server-pub>";
    allowedIPs = [ "10.100.0.0/24" ];
    endpoint = "<home-public-ip-or-ddns>:51820";
    persistentKeepalive = 25;
    presharedKeyFile = config.age.secrets.wg-psk.path;
  }];
};
```

### DNS
```nix
networking.extraHosts = ''
  10.100.0.1  server
  10.100.0.10 workstation
  10.100.0.20 laptop
'';
```

### Deliverables
- [ ] Confirmed public IP (no CGNAT) from ISP
- [ ] Static IP or DDNS configured
- [ ] Turris port forward: UDP 51820 -> server
- [ ] Server as WireGuard hub, all peers connected over 10.100.0.0/24
- [ ] wireguard.nix rewritten with agenix secrets
- [ ] Laptop can reach server/workstation from remote networks
- [ ] NordVPN remains separate (outbound privacy, not mesh)

### Optional: VPS relay (fallback)

If ISP has extended outages or you need geographic redundancy, a VPS relay can be added later as an additional WireGuard peer. The server remains primary hub; the VPS would only be needed if home internet is down.

---

## Phase 6: Backups (sanoid/syncoid)

**Goal:** Automated ZFS replication from all hosts to server.

### Sanoid (snapshot policy on server)
```nix
services.sanoid = {
  enable = true;
  datasets = {
    "tank/media" = {
      autosnap = true; autoprune = true;
      daily = 30; weekly = 4; monthly = 12;
    };
    "tank/backups" = {
      autosnap = true; autoprune = true;
      hourly = 24; daily = 30; weekly = 8; monthly = 12;
    };
    "tank/share" = {
      autosnap = true; autoprune = true;
      hourly = 24; daily = 30; monthly = 6;
    };
  };
};
```

### Syncoid (pull from workstation/laptop to server)
```nix
services.syncoid = {
  enable = true;
  interval = "hourly";
  commands = {
    "workstation-home" = {
      source = "oat@10.100.0.10:rpool/home";
      target = "tank/backups/workstation/home";
    };
    "laptop-home" = {
      source = "oat@10.100.0.20:rpool/home";
      target = "tank/backups/laptop/home";
    };
  };
};
```

### Optional offsite backup

If a VPS or remote host is added later:
```nix
services.syncoid.commands."offsite" = {
  source = "tank/backups";
  target = "oat@<remote-host>:offsite/backups";
  recursive = true;
};
```
Alternatives: Backblaze B2 with `zfs send` piped to `rclone`, or a friend's NAS.

### Deliverables
- [ ] sanoid running on server with retention policies
- [ ] syncoid pulling home datasets from workstation + laptop hourly
- [ ] SSH keys configured for syncoid over WireGuard

---

## Phase 7: Deployment Tooling (colmena)

**Goal:** Deploy all hosts from one machine.

### Add to flake.nix
```nix
inputs.colmena = {
  url = "github:zhaofengli/colmena";
  inputs.nixpkgs.follows = "nixpkgs";
};

outputs = { ... }: {
  colmena = {
    meta = {
      nixpkgs = import nixpkgs { system = "x86_64-linux"; };
      specialArgs = { inherit inputs; };
    };

    workstation-nixos = {
      deployment.targetHost = "10.100.0.10";
      deployment.targetUser = "oat";
      deployment.allowLocalDeployment = true;
      imports = [ ./hosts/workstation ];
    };

    laptop-nixos = {
      deployment.targetHost = "10.100.0.20";
      deployment.targetUser = "oat";
      imports = [ ./hosts/laptop ];
    };

    server-nixos = {
      deployment.targetHost = "10.100.0.1";
      deployment.targetUser = "oat";
      imports = [ ./hosts/server ];
    };
  };
};
```

### Usage
```bash
colmena apply                        # all hosts
colmena apply --on server-nixos      # one host
colmena build                        # check for errors
```

### Deliverables
- [ ] colmena in flake, all hosts defined
- [ ] Tested deploy to each host over WireGuard
- [ ] SSH keys configured for passwordless deploy

---

## Execution Order

```
Pre-req   Build custom installer ISO (Claude Code + ZFS + YubiKey)
  |
Phase 0   YubiKey provisioning (can use installer USB, airgapped)
  |
Phase 1   agenix secrets (no reinstall needed)
  |
Phase 2   Laptop ZFS reinstall (pilot — boot custom ISO)
  |         - validate: boot, hibernate, agenix, YubiKey, NordVPN
  |         - Claude available in installer for guided setup
  |
Phase 3   Workstation ZFS reinstall (same ISO)
  |         - validate: gaming perf, ARC tuning, /storage mirror
  |
Phase 4   Server ZFS install + services + network
  |         - Turris Omnia NG as router/firewall/WiFi 7 AP
  |         - Managed switch for wired devices + port mirroring
  |         - AdGuard Home on server, replace ISP router
  |         - can start in parallel once Phase 2 validates ZFS workflow
  |
Phase 5   WireGuard mesh (requires server + public IP from ISP)
  |         - server as hub, Turris port forward UDP 51820
  |         - no VPS needed — ISP provides public IP
  |
Phase 6   Backups (requires server + WireGuard mesh)
  |
Phase 7   colmena (requires WireGuard mesh)
  |
Phase 8   IDS/Network Analysis (optional, requires managed switch)
            - Suricata on server via mirror port
            - USB-C 2.5GbE adapter for second NIC
```

**Critical path:** Pre-req -> Phase 0 -> 1 -> 2 (laptop) -> 3 (workstation) -> 4 (server) -> 5 (WireGuard)

The custom ISO is reused for every host install. Server setup can start in parallel once the laptop validates the ZFS + agenix workflow. No VPS needed — server is the WireGuard hub with ISP public IP.

---

## Phase 8: IDS/Network Analysis (optional)

**Goal:** Intrusion detection and network traffic analysis using the managed switch's port mirroring.

**Prerequisite:** Phase 4 complete (managed switch + server running), USB-C 2.5GbE adapter installed on server.

### 8.1 Hardware Setup

The managed switch mirrors all traffic from the uplink port (or selected ports) to a dedicated mirror port. The Framework Server receives this mirrored traffic on a second NIC (USB-C to 2.5GbE adapter, ~$15).

```
Managed Switch
├── Port 1: Server — primary NIC (data, <lan-ip>)
├── Port 2: Server — secondary NIC (mirror/IDS, promiscuous)
│             └── USB-C 2.5GbE adapter
├── Mirror config: copy all traffic from SFP+ uplink → Port 2
└── ...
```

### 8.2 NixOS Interface Config
```nix
# Secondary NIC — no IP, promiscuous mode for packet capture
systemd.network.networks."30-ids" = {
  matchConfig.Name = "enp*usb*";  # USB-C adapter naming
  networkConfig = {
    DHCP = "no";
    LinkLocalAddressing = "no";
  };
  linkConfig.Promiscuous = true;
};
```

### 8.3 Suricata (IDS/IPS)
```nix
services.suricata = {
  enable = true;
  settings = {
    af-packet = [{
      interface = "enp*usb*";  # mirror port interface
      cluster-type = "cluster_flow";
      defrag = true;
    }];
    outputs = [{
      eve-log = {
        enabled = true;
        filetype = "regular";
        filename = "/var/log/suricata/eve.json";
        types = [
          { alert.payload = true; }
          { dns = {}; }
          { tls = {}; }
          { http = {}; }
          { flow = {}; }
        ];
      };
    }];
    default-rule-path = "/var/lib/suricata/rules";
    rule-files = [ "suricata.rules" ];
  };
};

# Auto-update rulesets (ET Open)
systemd.services.suricata-update = {
  description = "Update Suricata rulesets";
  serviceConfig.Type = "oneshot";
  serviceConfig.ExecStart = "${pkgs.suricata}/bin/suricata-update";
};
systemd.timers.suricata-update = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
};
```

### 8.4 Optional: Zeek (network analysis)
```nix
# Zeek for deeper protocol analysis (optional, heavier)
# environment.systemPackages = [ pkgs.zeek ];
```

### 8.5 Validate
- [ ] USB-C 2.5GbE adapter detected, interface in promiscuous mode
- [ ] Switch port mirroring configured and sending traffic to mirror port
- [ ] Suricata processing mirrored traffic, alerts in eve.json
- [ ] Rule updates running daily
- [ ] No performance impact on server primary NIC

### Deliverables
- [ ] Second NIC (USB-C adapter) installed on server
- [ ] Switch port mirroring configured
- [ ] Suricata running on mirrored traffic
- [ ] Alert logging configured (eve.json)
- [ ] Rule auto-update timer active

---

## New Files to Create

```
installer/
  default.nix                # custom ISO config (Claude, ZFS, LUKS, YubiKey)
  install.sh                 # interactive install script (host selection, LUKS, ZFS)
  refresh-flake.sh           # pull latest flake from GitHub to USB
  claude-config/
    CLAUDE.md                # repo CLAUDE.md copied in at build time
    LAB-REDEPLOYMENT.md      # this plan, available during install

hosts/common/optional/storage/
  zfs.nix                    # common ZFS (scrub, trim)
  luks.nix                   # LUKS2 + FIDO2 boot unlock

hosts/common/optional/networking/
  wireguard.nix              # rewrite: agenix secrets, mesh topology

secrets/
  secrets.nix                # agenix public key definitions (3 YubiKey age keys)
  wireguard/*.age            # encrypted WireGuard keys
  nordvpn/*.age              # encrypted VPN credentials
```

## Files to Modify

```
flake.nix                    # add installer ISO output, agenix, colmena inputs
hosts/laptop/default.nix     # add ZFS, hostId
hosts/workstation/default.nix # add ZFS, hostId, ARC cap
hosts/server/default.nix     # full rewrite: ZFS, services, WireGuard hub
hosts/common/core/packages.nix  # btrfs-progs -> zfs tooling
hosts/common/optional/power/hibernate.nix  # Btrfs swapfile -> zvol
hosts/common/optional/networking/nordvpn.nix  # plaintext key -> agenix
```

## Hardware Shopping List

All compute hardware is owned. Remaining purchases:

| Item | Spec | Est. Price |
|------|------|-----------|
| Rack | StarTech RK12WALLOA (19", 12U, wall-mount, adj depth) | ~$100 |
| Router/AP | Turris Omnia NG (OpenWrt, WiFi 7, 2x 10G SFP+, tri-band) | ~$350 |
| Switch | Managed 8-port 2.5GbE + SFP+ uplink (port mirroring) | ~$80 |
| USB-C 2.5GbE adapter | Second NIC for server IDS mirror port (Phase 8) | ~$15 |
| UPS | CyberPower OR500LCDRM1U or OR700LCDRM1U (1U/2U rack) | ~$180-220 |
| PDU | 1U rack-mount PDU (8-outlet) | ~$25 |
| Cantilever shelves | 2x 1U cantilever shelf (server + DAS) | ~$20 ea |
| DAS enclosure | ORICO or Sabrent 4-bay 2.5" USB-C | ~$40-60 |
| DAS drives | 2-4x 2.5" SATA SSD (e.g. 2TB Samsung 870 EVO) | ~$120-150 ea |
| Blanking panels | 2x solid + 2x vented (1U each) | ~$5-6 ea |
| Brush panel | 1x 1U brush cable management panel | ~$10 |
| Ethernet cables | Cat6 patch cables (short, color-coded) | ~$15 |
| E-ink display | Pimoroni Inky Impression 7.3" or Waveshare ACeP (7-color) | ~$65-75 |
| Pi Zero 2W | Drives e-ink display | ~$15 |
| SFP+ module | If ISP ONT has SFP+ output (optional) | ~$15 |
| Static IP (ISP) | Request from ISP if not already stable (may be free) | $0-10/mo |
| VPS (optional) | Offsite backup / fallback relay if needed later | ~$5/mo |
| **Total** | | **~$1,200-1,500** |
