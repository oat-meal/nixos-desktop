# NixOS Lab — Claude Code Context

## Host Detection

**On every new conversation**, run `hostname` to determine which host you're on, then load the appropriate host documentation:

| Hostname | Host Doc | Purpose |
|----------|----------|---------|
| `workstation-nixos` | `docs/audit/workstation.md` | Gaming workstation |
| `laptop-nixos` | `docs/audit/laptop.md` | Framework 13 laptop |
| `server-nixos` | `docs/audit/server.md` | Home server |

Read the host doc for hardware specs, known states, and audit history before making changes.

## Repository

- **Location**: `/etc/nixos/`
- **Remote**: `https://github.com/oat-meal/nixos-lab`
- **Type**: Nix Flakes with Home Manager
- **Channel**: nixpkgs-25.11 stable, selective unstable overlay (`pkgs.unstable.<pkg>`)

## Structure

```
hosts/
├── common/
│   ├── core/          # Required on ALL hosts (boot, locale, networking, nix, packages, shell, users)
│   └── optional/      # Mix-in modules (desktop/, gaming/, hardware/, networking/, power/, security/)
├── workstation/       # Gaming workstation config
├── laptop/            # Framework 13 config
├── server/            # Home server

home/
├── <user>/               # User-specific Home Manager config
└── common/optional/   # Shared HM modules (desktop/, user-packages.nix, theme.nix)

docs/
├── audit/             # Per-host audit framework
│   ├── README.md      # Audit checklist (9-step process)
│   ├── known-states.md # Expected anomalies (do not flag)
│   ├── workstation.md # Workstation hardware, audit history
│   └── laptop.md      # Laptop hardware, audit history
├── NORDVPN-SETUP.md   # wgnord VPN guide
└── NIRI-MIGRATION.md  # Historical (completed March 2026)
```

## Common Commands

```bash
# Rebuild (replace <hostname> with output of `hostname`)
sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)

# Dry run
sudo nixos-rebuild dry-activate --flake /etc/nixos#$(hostname)

# Update inputs
sudo nix flake update /etc/nixos

# Garbage collect
sudo nix-collect-garbage --delete-older-than 30d
```

## Multi-Host Workflow

This repo is shared across machines. Before editing:

```bash
cd /etc/nixos && sudo git pull --rebase
```

After committing:

```bash
cd /etc/nixos && sudo git push
```

On the other machine, pull before rebuilding.

## Audit Process

When performing a system audit, follow `docs/audit/README.md`. Check `docs/audit/known-states.md` before flagging issues — many apparent anomalies are documented and expected.

Record audit results in the host's doc file (`docs/audit/<host>.md`).

## Key Conventions

- **Module priority**: Use `lib.mkDefault` for common defaults, `lib.mkForce` for host overrides
- **Unstable packages**: Access via `pkgs.unstable.<package>` (overlay defined in flake.nix)
- **Desktop**: Niri scrollable tiling Wayland compositor on all desktop hosts
- **Theme**: Catppuccin Macchiato system-wide
- **Browser**: Zen Browser (sole browser)
- **Shell**: Zsh with Oh-My-Zsh
- **User**: Single user `<user>` with Home Manager

## Documentation Style

- Use factual, specification-focused language
- Replace "optimized/tuned/enhanced" with "configured/specified/set"
- State technical specifications, not performance promises
- Repo docs are the source of truth; Obsidian links back to them

## Symlink Setup

This file lives in the repo and should be symlinked on each host:

```bash
ln -sf /etc/nixos/CLAUDE.md ~/.claude/CLAUDE.md
```
