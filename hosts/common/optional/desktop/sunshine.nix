# Sunshine — game-stream host for playtesting from the laptop.
#
# Streams the workstation's live Mango session to Moonlight on laptop-nixos over wg0.
# Purpose-built low-latency video (H.264/HEVC/AV1 via the RX 9070 XT hardware encoder),
# chosen over waypipe/RDP for remote playtest feel — Claude builds on the workstation,
# this streams the app when it's launched. Imported by hosts/workstation only.
#
# First-run setup (once): open Sunshine's web UI at https://10.100.0.1:47990 (self-signed
# cert warning is expected) and create a web-UI username/password. In Moonlight on the
# laptop, add the host by IP 10.100.0.1 (mDNS/avahi discovery does not traverse wg0), then
# enter the PIN Sunshine shows to pair. Everything below is wg0-only.

{ pkgs, ... }:

{
  services.sunshine = {
    enable = true;
    # From unstable, NOT nixpkgs: CVE-2026-32253 (auth bypass — the TLS verify callback
    # treated UNABLE_TO_GET_ISSUER_CERT_LOCALLY / CERT_NOT_YET_VALID / CERT_HAS_EXPIRED
    # as success, so untrusted certs reached protected HTTPS endpoints) is fixed in
    # 2026.516.143833. nixos-25.11 froze at 2025.924.154138 before that landed and is
    # EOL, so no flake update will ever deliver it on this channel.
    # Drop this override once nixpkgs moves to 26.05, which carries the fixed version.
    package = pkgs.unstable.sunshine;
    # CAP_SYS_ADMIN for DRM/KMS capture of the Wayland (Mango/wlroots) session. Granted
    # only to the sunshine wrapper binary via security.wrappers.
    capSysAdmin = true;
    # Start with the graphical session so the stream is always available to attach to
    # while the workstation is logged in.
    autoStart = true;
    # Don't open on all interfaces; wg0-only rules below (lab pattern).
    openFirewall = false;
  };

  # wg0-only exposure. Ports mirror the module's own defaults for base port 47989:
  # TCP = base+{-5,0,1,21}, UDP = base+{9,10,11,13,21}.
  networking.firewall.interfaces."wg0" = {
    allowedTCPPorts = [ 47984 47989 47990 48010 ];
    allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
  };
}
