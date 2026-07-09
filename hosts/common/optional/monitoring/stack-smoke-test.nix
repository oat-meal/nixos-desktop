# AMD ROCm stack smoke test (daily canary).
#
# Runs ai-lab/smoke-test/smoke_test.py as oat on the workstation: a 1-token Ollama
# generation (gfx1151) + a tiny ComfyUI image gen (gfx1201). Alerts the lab ntfy
# hub if either fails — catches the documented fragility (a flake update breaking
# ollama-rocm or the RDNA4 ComfyUI image) before you hit it. Imported by the
# workstation (it can reach Ollama over wg0 + ComfyUI on loopback).

{ pkgs, ... }:

let
  smoke = pkgs.writeShellScriptBin "stack-smoke-test" ''
    export PATH=/run/current-system/sw/bin:$PATH
    exec ${pkgs.python3}/bin/python ${../../../../ai-lab/smoke-test/smoke_test.py} "$@"
  '';
in
{
  environment.systemPackages = [ smoke ];   # also runnable on demand

  systemd.services.stack-smoke-test = {
    description = "AMD ROCm stack smoke test (ollama + ComfyUI)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "oat";
      TimeoutStartSec = "300";
      Environment = [
        "OLLAMA_HOST_URL=http://10.100.0.2:11434"
        "COMFY_URL=http://127.0.0.1:8188"
        "SMOKE_MODEL=qwen2.5:7b"
        "NTFY_URL=http://10.100.0.2:2586/lab-alerts"
      ];
      ExecStart = "${smoke}/bin/stack-smoke-test";
    };
  };

  systemd.timers.stack-smoke-test = {
    description = "Daily AMD ROCm stack smoke test";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 08:15:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}
