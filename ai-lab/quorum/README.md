# Model Quorum

Ask several local models the same question **independently**, then reconcile their answers:
agreement raises confidence, disagreement is flagged. The goal is **cross-referencing to reduce
hallucinations** — not debate or voting.

Stdlib-only Python; talks to Ollama's HTTP API over wg0.

## Usage (on the server, or any host with python3 + mesh access)

```sh
OLLAMA_HOST=10.100.0.2:11434 python3 quorum.py "your question"

# pick members / reconciler:
python3 quorum.py --members qwen2.5:7b,llama3.3:70b --judge llama3.3:70b "your question"
```

Defaults: members = `qwen2.5:7b, qwen2.5-coder:32b, llama3.3:70b`; reconciler = `llama3.3:70b`.
Members are queried concurrently; expect the run to take as long as the slowest member + the
reconcile pass (the 70B is ~5 tok/s).

## How it works
1. Each member answers the question independently (no cross-talk).
2. A reconciler model cross-references the answers: keeps corroborated/correct claims, **flags
   disagreements as low-confidence**, and drops unsupported ones.

Exposed as the `lab-quorum` command (see `hosts/common/optional/ai/lab-tools.nix`).
