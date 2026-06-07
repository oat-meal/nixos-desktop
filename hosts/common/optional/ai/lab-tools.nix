# AI-lab CLI tools — clean commands for the stdlib Python tools in ai-lab/.
# lab-quorum / lab-rag / lab-research, available on the server.

{ pkgs, ... }:

let
  py = "${pkgs.python3}/bin/python3";
  tool = name: src: pkgs.writeShellScriptBin name ''exec ${py} ${src} "$@"'';
in
{
  environment.systemPackages = [
    (tool "lab-quorum" ../../../../ai-lab/quorum/quorum.py)
    (tool "lab-rag" ../../../../ai-lab/rag/rag.py)
    (tool "lab-research" ../../../../ai-lab/research/research.py)
  ];
}
