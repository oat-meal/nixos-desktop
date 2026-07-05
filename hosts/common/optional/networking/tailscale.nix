# Tailscale
# Mesh VPN (WireGuard-based) for joining a remote tailnet — e.g. a friend's
# network for LAN-style gaming. Client-only: no subnet routing or exit node.
#
# Coexists with the existing WireGuard mesh (wg0) and wgnord — different
# interface (tailscale0) and port, no conflict. Reverse-path filtering is
# already loose globally (networking/wireguard.nix forces all.rp_filter = 2),
# so Tailscale's direct peer connections are not blocked by hardening.nix.
#
# First-time setup (interactive, one-off — auth can't be declarative without
# an auth key):
#   sudo tailscale up
# then log in via the browser and accept the friend's tailnet / shared nodes.
# Check state with:  tailscale status
#
# Day-to-day on/off:  tstoggle
#   Runtime connect/disconnect (`tailscale up`/`down`) — the daemon keeps
#   running, so this just joins/leaves the tailnet. Instant, no rebuild, no
#   browser reauth. `oat` is set as the Tailscale operator below, so tstoggle
#   (and plain `tailscale up`/`down`) need no sudo.

{ pkgs, ... }:

let
  # Flip the tailnet connection based on the current backend state.
  tstoggle = pkgs.writeShellApplication {
    name = "tstoggle";
    runtimeInputs = [ pkgs.tailscale pkgs.jq ];
    text = ''
      state=$(tailscale status --json | jq -r '.BackendState')
      if [ "$state" = "Running" ]; then
        tailscale down
        echo "Tailscale: disconnected"
      else
        tailscale up
        echo "Tailscale: connected ($(tailscale ip -4 | head -n1))"
      fi
    '';
  };
in
{
  services.tailscale = {
    enable = true;

    # Open the firewall for Tailscale's UDP port so peers can establish DIRECT
    # connections instead of relaying through a DERP server. Direct paths matter
    # for gaming latency. The NixOS module also sets the firewall's reverse-path
    # check to "loose" for the tailscale interface.
    openFirewall = true;

    # Pure client: don't advertise subnet routes or act as an exit node.
    useRoutingFeatures = "none";
  };

  # Let oat drive the daemon (up/down/set) without sudo. Re-applied each boot as
  # a oneshot after tailscaled so the operator grant survives daemon restarts.
  systemd.services.tailscale-operator = {
    description = "Grant oat the Tailscale operator role";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.tailscale}/bin/tailscale set --operator=oat";
    };
  };

  # CLI (`tailscale up`, `tailscale status`, ...) plus the tstoggle helper. The
  # service already pulls in the daemon; this ensures the commands are on PATH.
  environment.systemPackages = [ pkgs.tailscale tstoggle ];
}
