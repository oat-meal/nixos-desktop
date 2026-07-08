#!/usr/bin/env python3
"""Ollama LLM benchmark — measured against a running Ollama endpoint.

Reports, per generative model: cold load time, prefill (prompt-eval) tok/s,
generation tok/s, warm time-to-first-token, resident VRAM, and GPU placement.
Embedding models report embeddings/s. Deterministic (temperature 0, fixed
seed, fixed prompt) so runs are comparable across hardware.

Usage:  python3 llm_bench.py [http://HOST:11434]
The Ollama service binds to the wg0 IP, so the CLI needs OLLAMA_HOST set;
this script just points at the same URL.
"""
import json, sys, time, urllib.request

HOST = sys.argv[1] if len(sys.argv) > 1 else "http://10.100.0.2:11434"
GEN_MODELS = ["qwen2.5:7b", "dolphin3:8b", "qwen3:30b-a3b", "qwen2.5-coder:32b",
              "llama3.3:70b", "qwen2.5vl:7b"]
EMBED_MODELS = ["nomic-embed-text", "bge-m3"]
NUM_PREDICT = 256

PROMPT = (
    "You are a systems engineer writing documentation. In a few paragraphs, "
    "explain how a modern CPU's multi-level cache hierarchy (L1, L2, L3) works, "
    "why cache lines and spatial locality matter for performance, how cache "
    "coherence is maintained across cores in a multi-socket system, and what "
    "practical steps a programmer can take to write cache-friendly code. Be "
    "concrete and technical, and use examples where helpful."
)


def post(path, payload):
    req = urllib.request.Request(
        HOST + path, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)


def ps():
    req = urllib.request.Request(HOST + "/api/ps")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def bench_gen(model):
    # First call cold-loads the model and captures load_duration; second is warm.
    opts = {"temperature": 0, "seed": 42, "num_predict": NUM_PREDICT}
    cold = post("/api/generate", {"model": model, "prompt": PROMPT,
                "stream": False, "options": opts})
    load_s = cold.get("load_duration", 0) / 1e9
    placement, size_vram = "", 0
    try:
        for m in ps().get("models", []):
            if m.get("name", "").startswith(model) or m.get("model", "").startswith(model):
                total = m.get("size", 0); size_vram = m.get("size_vram", 0)
                placement = f"{round(100 * size_vram / total)}% GPU" if total else ""
    except Exception as e:
        placement = f"ps? {e}"
    warm = post("/api/generate", {"model": model, "prompt": PROMPT,
                "stream": False, "options": opts})
    pe_n, pe_d = warm["prompt_eval_count"], warm["prompt_eval_duration"] / 1e9
    ev_n, ev_d = warm["eval_count"], warm["eval_duration"] / 1e9
    return {"model": model, "load_s": round(load_s, 2),
            "prompt_tokens": pe_n, "prefill_tps": round(pe_n / pe_d, 1) if pe_d else 0,
            "gen_tokens": ev_n, "gen_tps": round(ev_n / ev_d, 1) if ev_d else 0,
            "ttft_warm_s": round(pe_d, 3), "vram_gb": round(size_vram / 1e9, 1),
            "placement": placement}


def bench_embed(model):
    n, toks, t0 = 20, 0, time.time()
    for _ in range(n):
        toks = post("/api/embed", {"model": model, "input": PROMPT}).get("prompt_eval_count", 0)
    dt = time.time() - t0
    return {"model": model, "embeds_per_s": round(n / dt, 1),
            "tokens_each": toks, "batch": n, "total_s": round(dt, 2)}


def main():
    results = {"host": HOST, "gen": [], "embed": []}
    for m in GEN_MODELS:
        print(f"# benching {m} ...", file=sys.stderr, flush=True)
        try:
            results["gen"].append(bench_gen(m))
        except Exception as e:
            results["gen"].append({"model": m, "error": str(e)})
    for m in EMBED_MODELS:
        print(f"# benching {m} (embed) ...", file=sys.stderr, flush=True)
        try:
            results["embed"].append(bench_embed(m))
        except Exception as e:
            results["embed"].append({"model": m, "error": str(e)})
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
