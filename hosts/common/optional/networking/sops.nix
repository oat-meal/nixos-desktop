# sops-nix — runtime secrets decryption
# Decrypts secrets/secrets.yaml at activation using the host's SSH key

{ config, ... }:

let
  hostname = config.networking.hostName;
in
{
  sops = {
    defaultSopsFile = ../../../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."wireguard/${hostname}" = {
      owner = "root";
      mode = "0600";
    };
  };
}
