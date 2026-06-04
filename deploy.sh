#!/usr/bin/env bash
# Deploy nixos-lab to all hosts
# Usage: deploy.sh [target...]
#   local              — rebuild this host (default)
#   server-nixos       — push + rebuild server
#   laptop-nixos       — push + rebuild laptop
#   workstation-nixos   — push + rebuild workstation
#   all                — rebuild local, push, rebuild all remotes
set -euo pipefail

FLAKE="/etc/nixos"
LOCAL=$(hostname)

confirm() {
  local msg="$1"
  echo ""
  echo "$msg"
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
}

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
  ssh "$host" "sudo git -C /etc/nixos -c core.sshCommand='ssh -i /home/oat/.ssh/id_ed25519 -o IdentitiesOnly=yes' pull --rebase && sudo nixos-rebuild switch --flake /etc/nixos#$host"
}

# No args = local
targets=("${@:-local}")

# Validate targets
valid_targets="local all server-nixos laptop-nixos workstation-nixos"
for target in "${targets[@]}"; do
  if [[ ! " $valid_targets " =~ " $target " ]]; then
    echo "Unknown target: $target"
    echo "Usage: deploy.sh [local|all|server-nixos|laptop-nixos|workstation-nixos]"
    exit 1
  fi
done

# Show plan and confirm
echo "Deploy plan:"
echo "  Host:    $LOCAL"
echo "  Targets: ${targets[*]}"
echo "  Flake:   $FLAKE"

cd "$FLAKE"
changes=$(git status --short 2>/dev/null)
if [[ -n "$changes" ]]; then
  echo ""
  echo "Uncommitted changes:"
  echo "$changes"
fi

# Pre-flight: verify all target configs evaluate
echo ""
echo "==> Pre-flight: evaluating flake configurations..."
eval_targets=()
for target in "${targets[@]}"; do
  case "$target" in
    local) eval_targets+=("$LOCAL") ;;
    all) eval_targets+=(workstation-nixos laptop-nixos server-nixos) ;;
    *) eval_targets+=("$target") ;;
  esac
done
# Deduplicate
eval_targets=($(printf '%s\n' "${eval_targets[@]}" | sort -u))
for host in "${eval_targets[@]}"; do
  if ! nix eval "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel.drvPath" >/dev/null 2>&1; then
    echo "FAIL: $host config does not evaluate cleanly"
    nix eval "$FLAKE#nixosConfigurations.$host.config.system.build.toplevel.drvPath" 2>&1 | tail -5
    exit 1
  fi
  echo "  $host: OK"
done

confirm "Proceed with deployment?"

for target in "${targets[@]}"; do
  case "$target" in
    local)
      rebuild_local
      ;;
    all)
      rebuild_local
      push_repo
      for remote in server-nixos laptop-nixos workstation-nixos; do
        [ "$remote" = "$LOCAL" ] && continue
        confirm "Rebuild $remote?"
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
