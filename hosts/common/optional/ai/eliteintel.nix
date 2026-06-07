# EliteIntel co-pilot — declarative package on the gaming host.
# Provides the `eliteintel` command + desktop entry. Runs the bundled sherpa-onnx
# STT/TTS locally; point its LLM at the server's Ollama (10.100.0.2:11434).

{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.callPackage ../../../../ai-lab/eliteintel/package.nix { })
  ];
}
