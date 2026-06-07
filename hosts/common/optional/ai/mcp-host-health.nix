# host-health MCP server (declarative)
# Read-only system health tools for Claude Code, served over stdio via `ssh` on wg0.
# Replaces the old imperative ~/.config/mcp/host-health (uv + .venv).

{ pkgs, ... }:

let
  secrets = import ../../../../secrets/network.nix;

  # Python env with just the MCP SDK (provides mcp.server.fastmcp). No venv needed.
  pyEnv = pkgs.python3.withPackages (ps: [ ps.mcp ]);

  # Wrapper Claude Code invokes as `ssh server-nixos host-health-mcp`.
  # PATH covers zfs/zpool/systemctl/journalctl/ollama in a minimal ssh session;
  # OLLAMA_HOST points the `ollama` CLI at the wg0-bound server instance.
  host-health-mcp = pkgs.writeShellScriptBin "host-health-mcp" ''
    export PATH=/run/current-system/sw/bin:$PATH
    export OLLAMA_HOST=10.100.0.2:11434
    exec ${pyEnv}/bin/python ${../../../../ai-lab/mcp/host-health/server.py} "$@"
  '';
in
{
  environment.systemPackages = [ host-health-mcp ];

  # Let the health tools read the journal without sudo.
  users.users.${secrets.user}.extraGroups = [ "systemd-journal" ];
}
