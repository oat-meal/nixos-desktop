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
    ];
  }];
}
