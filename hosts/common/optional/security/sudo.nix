# Scoped passwordless sudo for system management
# Hosts can extend with additional commands via lib.mkAfter

{ ... }:

{
  security.sudo.extraRules = [{
    users = [ "oat" ];
    commands = [
      { command = "/run/current-system/sw/bin/nixos-rebuild"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/nix*"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/git"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zfs"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/zpool"; options = [ "NOPASSWD" ]; }

      # Network diagnosis. Added 2026-08-16 (oat-approved) after container-port
      # reachability could not be diagnosed without reading the live ruleset: every
      # NATIVE service on server-nixos answered over wg0 (ollama 11434, adguard 3000,
      # ntfy 2586, lab-api 8091) while BOTH podman published ports were blocked
      # (comfyui 8188, kokoro 8880) — and 8188 is present in the evaluated
      # wg0.allowedTCPPorts, so the declared config looked correct for both.
      #
      # This grants rule MODIFICATION, not just inspection: sudoers cannot usefully
      # constrain iptables by argument, since -L and -A differ by one flag. That is
      # acceptable here only because `nixos-rebuild` and `nix*` above are already
      # root-equivalent by construction — anyone who can build and switch a system
      # closure can do anything. This widens diagnostic reach, not privilege.
      #
      # nft is included for when/if the firewall backend moves off iptables;
      # ss needs root for -p (owning process), which is what identifies a listener.
      { command = "/run/current-system/sw/bin/iptables"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/ip6tables"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/nft"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/ss"; options = [ "NOPASSWD" ]; }
    ];
  }];
}
