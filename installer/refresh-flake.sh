#!/usr/bin/env bash
# Refresh the local flake copy from GitHub
set -euo pipefail

REPO_URL="https://github.com/oat-meal/nixos-lab.git"
PERSISTENT_LABEL="NIXOS-DATA"
PERSISTENT_MNT="/mnt/usb-data"

echo -e "\033[0;34m[INFO]\033[0m Refreshing flake from GitHub..."

# Find and mount persistent partition
persistent_dev=$(blkid -L "$PERSISTENT_LABEL" 2>/dev/null || true)

if [[ -z "$persistent_dev" ]]; then
    echo -e "\033[1;33m[WARN]\033[0m No persistent partition (label=$PERSISTENT_LABEL) found."
    echo "       Cloning directly to /tmp/nixos-lab instead."
    target="/tmp/nixos-lab"
else
    mkdir -p "$PERSISTENT_MNT"
    if ! mountpoint -q "$PERSISTENT_MNT"; then
        mount "$persistent_dev" "$PERSISTENT_MNT"
    fi
    target="$PERSISTENT_MNT/nixos-lab"
fi

if [[ -d "$target/.git" ]]; then
    echo -e "\033[0;34m[INFO]\033[0m Pulling latest changes..."
    git -C "$target" pull --rebase
else
    echo -e "\033[0;34m[INFO]\033[0m Cloning repo..."
    rm -rf "$target"
    git clone "$REPO_URL" "$target"
fi

echo -e "\033[0;32m[OK]\033[0m Flake updated at: $target"
echo "     Latest commit: $(git -C "$target" log --oneline -1)"
