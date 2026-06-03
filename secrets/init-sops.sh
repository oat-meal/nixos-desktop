#!/usr/bin/env bash
# Initialize sops secrets with WireGuard private keys from all hosts
# Run from workstation with WireGuard mesh active
set -euo pipefail

SECRETS_FILE="/etc/nixos/secrets/secrets.yaml"

echo "Collecting WireGuard private keys from all hosts..."
echo ""

# Workstation (local)
echo "==> Reading workstation key (may prompt for sudo password)..."
ws_key=$(sudo cat /etc/wireguard/private.key)
echo "    OK (${#ws_key} chars)"

# Remote hosts — sudo cat isn't passwordless, so prompt for paste
echo ""
echo "==> Run on server-nixos:  sudo cat /etc/wireguard/private.key"
read -r -p "    Paste server key: " srv_key
[[ ${#srv_key} -eq 44 ]] || { echo "    ERROR: expected 44 chars, got ${#srv_key}. Aborting."; exit 1; }
echo "    OK"

echo ""
echo "==> Run on laptop-nixos:  sudo cat /etc/wireguard/private.key"
read -r -p "    Paste laptop key: " lap_key
[[ ${#lap_key} -eq 44 ]] || { echo "    ERROR: expected 44 chars, got ${#lap_key}. Aborting."; exit 1; }
echo "    OK"

echo ""
echo "Writing $SECRETS_FILE..."

cat > "$SECRETS_FILE" <<EOF
wireguard:
    workstation-nixos: $ws_key
    server-nixos: $srv_key
    laptop-nixos: $lap_key
EOF

echo ""
echo "Keys written. Verifying format..."
if grep -q "REPLACE" "$SECRETS_FILE"; then
  echo "ERROR: placeholders still present. Aborting."
  exit 1
fi

echo ""
read -r -p "Encrypt with sops? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "Aborted. WARNING: plaintext keys in $SECRETS_FILE — delete if not needed."
  exit 1
fi

echo "==> Encrypting..."
nix-shell -p sops age ssh-to-age --run "sops --encrypt --in-place $SECRETS_FILE"

echo ""
echo "Done. $SECRETS_FILE is now encrypted."
echo "To edit later: nix-shell -p sops age ssh-to-age --run 'sops $SECRETS_FILE'"
