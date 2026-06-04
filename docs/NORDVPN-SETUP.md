# NordVPN Setup Guide (wgnord)

## Configuration Status
- ✅ wgnord installed
- ✅ WireGuard tools installed
- ✅ Firewall enabled with VPN support
- ✅ Helper scripts configured
- ⏳ **Next: Get your NordVPN access token and connect**

## Step 1: Get Your NordVPN Access Token

1. Go to: https://my.nordaccount.com/dashboard/nordvpn/access-tokens
2. Log in with your NordVPN account
3. Click "Generate new token"
4. Give it a name (e.g., "NixOS Desktop")
5. Copy the token (you'll only see it once!)

## Step 2: Configure wgnord with Your Token

After rebuilding your system, run:

```bash
# Store your NordVPN access token
sudo wgnord login <YOUR_ACCESS_TOKEN>
```

## Step 3: Connect to NordVPN

### Basic Connection

```bash
# Connect to fastest server
nordvpn connect us

# Connect to specific country
nordvpn connect uk
nordvpn connect ca
nordvpn connect de
```

### Check Status

```bash
# View connection status
nordvpn status

# Show WireGuard details
sudo wg show
```

### Disconnect

```bash
nordvpn disconnect
```

### List Available Servers

```bash
nordvpn list
```

## Advanced Usage

### Direct wgnord Commands

If you need more control:

```bash
# Connect to specific server
sudo wgnord connect us1234

# Use specific protocol
sudo wgnord connect --technology nordlynx us

# Show help
wgnord --help
```

### VPN Kill Switch (Optional)

If you want to prevent all internet traffic when VPN is disconnected, edit `/etc/nixos/hosts/common/optional/networking/nordvpn.nix` and uncomment the "VPN Kill Switch" section at the bottom.

**Warning**: With kill switch enabled, you won't have internet unless VPN is connected. Good for privacy, but can break things if VPN disconnects unexpectedly.

## Gaming with VPN

### Performance Tips

1. **Choose nearby servers**: Lower latency for gaming
   ```bash
   nordvpn connect us  # If you're in North America
   ```

2. **Use NordLynx protocol**: Already configured (WireGuard-based, fastest)

3. **Check latency before gaming**:
   ```bash
   ping -c 5 google.com
   ```

### Steam Remote Play with VPN

Steam Remote Play ports are already configured to work through the VPN. If you have connection issues:

```bash
# Temporarily allow specific ports
sudo firewall-cmd --add-port=27036-27037/tcp  # If using firewalld
```

## Troubleshooting

### "Connection failed" error

```bash
# Check if WireGuard module is loaded
lsmod | grep wireguard

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

### DNS not working

```bash
# Check DNS resolution
resolvectl status

# Manually set DNS (if needed)
sudo resolvectl dns wgnord 103.86.96.100 103.86.99.100
```

### Can't authenticate

```bash
# Re-login with token
sudo wgnord logout
sudo wgnord login <YOUR_TOKEN>
```

### VPN connected but no internet

```bash
# Check routing
ip route show

# Check firewall
sudo nft list ruleset | grep wgnord
```

## Security Notes

- **Firewall is now enabled**: This blocks unwanted incoming connections
- **Steam ports**: Still open for Remote Play (local network only)
- **VPN traffic**: Encrypted via WireGuard (NordLynx)
- **DNS**: Configured to use NordVPN's DNS servers when connected

## Quick Reference

| Command | Action |
|---------|--------|
| `nordvpn connect us` | Connect to US server |
| `nordvpn disconnect` | Disconnect from VPN |
| `nordvpn status` | Show connection status |
| `nordvpn list` | List available countries |
| `sudo wg show` | Show WireGuard details |

## Next Steps

1. Rebuild your system: `sudo nixos-rebuild switch --flake /etc/nixos#workstation-nixos`
2. Get your access token from NordVPN dashboard
3. Run: `sudo wgnord login <TOKEN>`
4. Connect: `nordvpn connect us`
5. Test: `curl ifconfig.me` (should show VPN IP)

## Configuration Files

- `/etc/nixos/hosts/common/optional/networking/nordvpn.nix` — WireGuard VPN, firewall, helper scripts
- `/etc/nixos/home/<user>/default.nix` — Waybar VPN status module
