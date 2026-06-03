#!/usr/bin/env bash
# Deploy nixos-lab to all hosts
# Usage: deploy.sh [host...]
# No args = rebuild local only. "all" = local + server + laptop.
set -euo pipefail

FLAKE="/etc/nixos"
LOCAL=$(hostname)

rebuild_local() {
  echo "==> Rebuilding $LOCAL"
  sudo nixos-rebuild switch --flake "$FLAKE#$LOCAL"
}

push_repo() {
  echo "==> Pushing to git"
  cd "$FLAKE"
  nix-shell -p git-crypt --run 'git add -A && git push'
}

rebuild_remote() {
  local host="$1"
  echo "==> Rebuilding $host"
  # Use WireGuard mesh IPs for SSH (laptop only allows SSH over wg0)
  ssh "$host" "cd /etc/nixos && sudo git pull --rebase && sudo nixos-rebuild switch --flake /etc/nixos#$host"
}

# Parse args
targets=("${@:-local}")

for target in "${targets[@]}"; do
  case "$target" in
    local)
      rebuild_local
      ;;
    all)
      rebuild_local
      push_repo
      for remote in server-nixos laptop-nixos; do
        [ "$remote" = "$LOCAL" ] && continue
        rebuild_remote "$remote"
      done
      exit 0
      ;;
    server-nixos|laptop-nixos|workstation-nixos)
      if [ "$target" = "$LOCAL" ]; then
        rebuild_local
      else
        push_repo
        rebuild_remote "$target"
      fi
      ;;
    *)
      echo "Unknown target: $target"
      echo "Usage: deploy.sh [local|all|server-nixos|laptop-nixos|workstation-nixos]"
      exit 1
      ;;
  esac
done
