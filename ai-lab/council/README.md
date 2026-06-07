# Model Council

Fan a prompt out to several local models, then have a judge model synthesize the best answer —
the Odysseus "council" concept, scaled to one Strix Halo box.

Stdlib-only Python; talks to Ollama's HTTP API over wg0.

## Usage (on the server, or any host with python3 + mesh access)

```sh
OLLAMA_HOST=10.100.0.2:11434 python3 council.py "your question"

# pick members / judge:
python3 council.py --members qwen2.5:7b,llama3.3:70b --judge llama3.3:70b "your question"
```

Defaults: members = `qwen2.5:7b, qwen2.5-coder:32b, llama3.3:70b`; judge = `llama3.3:70b`.
Members are queried concurrently; expect the run to take as long as the slowest member + the
judge pass (the 70B is ~5 tok/s).

## Notes
- A future `lab-council` Nix wrapper (like `host-health-mcp`) can make this a clean command.
- This is the first Phase 3 building block; next: RAG memory (ChromaDB + nomic-embed) and a
  model router.
