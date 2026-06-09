# SillyTavern — roleplay frontend (character cards, user persona, group chats).
# Points at the local Ollama; can also drive ComfyUI for images (configured in its UI).
# wg0-only, bound to the mesh IP; firewall is the access gate (same model as the other
# lab services), so the built-in whitelist is disabled via securityOverride.

{ pkgs, ... }:

let
  st = pkgs.sillytavern; # stable 1.13.x — matches the nixpkgs module's expected layout
  # Start from the package's default config.yaml and only relax the network guard —
  # all other keys stay at upstream defaults. (find handles either config.yaml location.)
  stConfig = pkgs.runCommand "sillytavern-config.yaml" { } ''
    src=$(${pkgs.findutils}/bin/find ${st}/lib/node_modules/sillytavern -maxdepth 2 -name config.yaml | head -1)
    cp "$src" $out
    chmod +w $out
    ${pkgs.gnused}/bin/sed -i \
      -e 's/^whitelistMode:.*/whitelistMode: false/' \
      -e 's/^securityOverride:.*/securityOverride: true/' \
      $out
    grep -q '^securityOverride:' $out || printf '\nsecurityOverride: true\n' >> $out
    grep -q '^whitelistMode:' $out  || printf '\nwhitelistMode: false\n'  >> $out
  '';
in
{
  services.sillytavern = {
    enable = true;
    package = st;
    listen = true;
    listenAddressIPv4 = "10.100.0.2"; # wg0
    port = 8002; # 8000 = ChromaDB, 8001 reserved, 8002 free
    configFile = "${stConfig}"; # string path (tmpfiles arg requires a string)
  };

  # Bind only after the WireGuard interface exists (it listens on the wg0 IP).
  systemd.services.sillytavern = {
    after = [ "wireguard-wg0.service" ];
    wants = [ "wireguard-wg0.service" ];
  };

  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 8002 ];
}
