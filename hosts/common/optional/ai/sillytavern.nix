# SillyTavern — roleplay frontend (character cards, user persona, group chats).
# Points at the local Ollama; can also drive ComfyUI for images (configured in its UI).
# wg0-only, bound to the mesh IP; firewall is the access gate (same model as the other
# lab services), so the built-in whitelist is disabled via securityOverride.

{ pkgs, lib, ... }:

let
  st = pkgs.sillytavern; # stable 1.13.x — matches the nixpkgs module's expected layout
  # World Weaver extension — registers function tools so a tool-calling model can build/extend
  # World Info natively in chat (requires Chat Completion + function calling). Zero app-module
  # imports, so it installs as a local third-party extension in the writable data dir.
  worldweaver = ../../../../ai-lab/sillytavern/extensions/worldweaver;
  installWorldweaver = pkgs.writeShellScript "install-worldweaver" ''
    ext="/var/lib/SillyTavern/data/default-user/extensions"
    # user extensions live directly in extensions/<name> (discover reads subfolders as
    # third-party/<name>); remove the mis-placed v1 copy under an extra third-party/ dir.
    ${pkgs.coreutils}/bin/rm -rf "$ext/third-party/worldweaver"
    ${pkgs.coreutils}/bin/rmdir "$ext/third-party" 2>/dev/null || true
    d="$ext/worldweaver"
    ${pkgs.coreutils}/bin/mkdir -p "$d"
    ${pkgs.coreutils}/bin/cp -f ${worldweaver}/manifest.json ${worldweaver}/index.js "$d/"
  '';
  # Start from the package's default config.yaml and only relax the network guard —
  # all other keys stay at upstream defaults. (find handles either config.yaml location.)
  stConfig = pkgs.runCommand "sillytavern-config.yaml" { } ''
    src=$(${pkgs.findutils}/bin/find ${st}/lib/node_modules/sillytavern -maxdepth 2 -name config.yaml | head -1)
    cp "$src" $out
    chmod +w $out
    ${pkgs.gnused}/bin/sed -i \
      -e 's/^listen:.*/listen: true/' \
      -e 's/^whitelistMode:.*/whitelistMode: false/' \
      -e 's/^securityOverride:.*/securityOverride: true/' \
      $out
    grep -q '^listen:' $out          || printf '\nlisten: true\n'          >> $out
    grep -q '^securityOverride:' $out || printf '\nsecurityOverride: true\n' >> $out
    grep -q '^whitelistMode:' $out  || printf '\nwhitelistMode: false\n'  >> $out
  '';
in
{
  services.sillytavern = {
    enable = true;
    package = st;
    # listen:true is set in the config (CLI flags didn't override it on 1.13); ST then
    # binds 0.0.0.0:8002, but the firewall opens 8002 ONLY on wg0 → mesh-only in practice.
    port = 8002; # 8000 = ChromaDB, 8001 reserved, 8002 free
    configFile = "${stConfig}"; # string path (tmpfiles arg requires a string)
  };

  # Bind only after the WireGuard interface exists (it listens on the wg0 IP), and drop the
  # World Weaver extension into the data dir before each start (runs as the sillytavern user).
  systemd.services.sillytavern = {
    after = [ "wireguard-wg0.service" ];
    wants = [ "wireguard-wg0.service" ];
    serviceConfig.ExecStartPre = lib.mkAfter [ "${installWorldweaver}" ];
  };

  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 8002 ];
}
