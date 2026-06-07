#!/usr/bin/env python3
"""Model council — fan a prompt out to several local models, then have a judge
model synthesize the best answer (the Odysseus "council" concept).

Stdlib only. Talks to Ollama's HTTP API over the WireGuard mesh.

Usage:
    OLLAMA_HOST=10.100.0.2:11434 python3 council.py "your question"
    python3 council.py --members qwen2.5:7b,llama3.3:70b "your question"
"""

import argparse
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HOST = os.environ.get("OLLAMA_HOST", "10.100.0.2:11434")
BASE = f"http://{HOST}"
DEFAULT_MEMBERS = ["qwen2.5:7b", "qwen2.5-coder:32b", "llama3.3:70b"]
DEFAULT_JUDGE = "llama3.3:70b"


def generate(model: str, prompt: str, timeout: int = 300) -> str:
    """One non-streaming completion from a model."""
    body = json.dumps({"model": model, "prompt": prompt, "stream": False}).encode()
    req = urllib.request.Request(
        f"{BASE}/api/generate", data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())["response"].strip()


def ask_member(model: str, question: str) -> tuple[str, str]:
    try:
        return model, generate(model, question)
    except Exception as e:  # noqa: BLE001 - report, don't crash the council
        return model, f"[error: {e}]"


def main() -> int:
    ap = argparse.ArgumentParser(description="Local model council")
    ap.add_argument("question", help="the prompt to put to the council")
    ap.add_argument("--members", help="comma-separated model list",
                    default=",".join(DEFAULT_MEMBERS))
    ap.add_argument("--judge", default=DEFAULT_JUDGE, help="synthesizer model")
    args = ap.parse_args()

    members = [m.strip() for m in args.members.split(",") if m.strip()]
    print(f"== Council ({len(members)} members) on {HOST} ==\n")

    # Fan out concurrently.
    with ThreadPoolExecutor(max_workers=len(members)) as pool:
        answers = list(pool.map(lambda m: ask_member(m, args.question), members))

    for model, ans in answers:
        print(f"--- {model} ---\n{ans}\n")

    # Judge synthesizes.
    transcript = "\n\n".join(f"### Answer from {m}:\n{a}" for m, a in answers)
    judge_prompt = (
        f"Question:\n{args.question}\n\n"
        f"Several models answered below. Synthesize the single best, most accurate "
        f"answer. Resolve disagreements, drop anything wrong, and be concise.\n\n"
        f"{transcript}\n\n### Synthesized best answer:"
    )
    print(f"== Synthesis (judge: {args.judge}) ==\n")
    try:
        print(generate(args.judge, judge_prompt))
    except Exception as e:  # noqa: BLE001
        print(f"[judge error: {e}]")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
