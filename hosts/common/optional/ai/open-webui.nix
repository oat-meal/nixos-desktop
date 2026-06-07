# Open WebUI — web chat frontend for the local Ollama models.
# wg0-only; reachable from the workstation browser over the mesh.

{ ... }:

{
  services.open-webui = {
    enable = true;
    host = "10.100.0.2"; # wg0
    port = 8080;
    openFirewall = false; # firewall handled centrally (wg0-only)
    environment = {
      # Talk to the local Ollama over wg0.
      OLLAMA_BASE_URL = "http://10.100.0.2:11434";
      # Local RAG embeddings via Ollama (no HF downloads).
      RAG_EMBEDDING_ENGINE = "ollama";
      RAG_EMBEDDING_MODEL = "nomic-embed-text";
      # Auth on; first account becomes admin. Disable signup after creating it.
      WEBUI_AUTH = "True";
      ENABLE_SIGNUP = "True";
      # No telemetry / phone-home.
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      HF_HUB_OFFLINE = "1";
    };
  };
}
