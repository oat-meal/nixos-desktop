# AI Lab

A self-hosted, local-first AI stack running entirely on consumer AMD hardware over a
private WireGuard mesh. No cloud inference — every model below runs on-prem. This page
documents what the lab runs, what each model is for, and how it actually performs on
this hardware (measured, not estimated).

> All services are bound to the `wg0` mesh only (see [README](../README.md#networking)).
> Hostnames here are examples — see the repo [Conventions](../README.md#conventions).

## Hardware & roles

| Host | CPU | RAM | GPU | Role |
|------|-----|-----|-----|------|
| `server-nixos` | Ryzen AI Max+ 395 (Strix Halo) | 128 GB unified | Radeon 8060S iGPU — `gfx1151`, RDNA 3.5 | **LLM + embedding tier** |
| `workstation-nixos` | Ryzen 9950X | 64 GB | Radeon RX 9070 XT — `gfx1201`, RDNA 4, 16 GB | **Image-generation render node** |
| `laptop-nixos` | Framework 13, Ryzen | 32 GB | iGPU | Client |

**On the Strix Halo memory model:** the iGPU shares system memory. The usable model
ceiling is the ~62 GB GTT pool, *not* the nominal 128 GB — and `mem_info_vram_total`
reports only 512 MiB, which is misleading; GTT is the pool that matters. ZFS ARC is
capped at 32 GB to leave headroom.

## Language models

Served by Ollama 0.24.0 (`ollama-rocm`, native `gfx1151`), flash attention on,
`num_ctx` 8192, 2 parallel slots.

| Model | Params | Purpose / strengths |
|-------|--------|---------------------|
| `qwen3:30b-a3b` | 30B MoE (~3B active) | **Primary daily driver.** Mixture-of-Experts: 30B-class quality at small-model speed — the fastest generative model in the lab (see benchmarks). Strong general reasoning. The architectural sweet spot for a memory-rich / compute-modest iGPU. |
| `qwen2.5:7b` | 7B dense | Lightweight general chat; lowest VRAM, snappy. |
| `dolphin3:8b` | 8B dense | Uncensored/steerable general assistant for unconstrained tasks. |
| `qwen2.5-coder:32b` | 32B dense | Code generation and review; best-in-class open coding model. |
| `llama3.3:70b` | 70B dense | Highest-capability general/reasoning model; slowest — use when quality beats latency. |
| `qwen2.5vl:7b` | 7B VLM | Vision-language: image captioning, OCR, screenshot understanding, and critiquing generated images. Bridges the image-gen pipeline back into text. |

### Embeddings

| Model | Purpose / strengths |
|-------|---------------------|
| `nomic-embed-text` | Fast general-purpose retrieval embeddings — the RAG default. |
| `bge-m3` | Multilingual, multi-vector; higher retrieval quality at lower throughput. |

## Image models

Served by ComfyUI 0.15.0 (PyTorch 2.12 + ROCm 7.2) on the RX 9070 XT.

| Checkpoint | Purpose / strengths |
|-----------|---------------------|
| `FLUX.1-schnell` (fp8) | Current-generation quality; 4-step distilled, Apache-2.0. Best default for quality-per-second. Runs in 16 GB via fp8 + text-encoder offload to system RAM. |
| `SDXL base 1.0` | Baseline SDXL reference. |
| `Juggernaut-XL v9` | Photoreal SDXL. |
| `Illustrious-XL v1.0` | Anime / illustration SDXL. |
| _also present_ | `RealVisXL v5`, `Raemu-XL v5`, `animagine-xl 4.0`. |

Quality/detail nodes: Impact Pack (FaceDetailer), Ultimate SD Upscale, IP-Adapter
FaceID, ESRGAN/UltraSharp upscalers.

> FLUX.1-dev (higher quality, non-commercial license, HF-gated) is not installed —
> it can be added by accepting its license with a Hugging Face token.

## Benchmarks

Measured **2026-07-08**. Method:

- **LLM** — via the Ollama HTTP API, deterministic (`temperature 0`, `seed 42`),
  ~100-token prompt, 256-token generation, `num_ctx` 8192, flash attention on.
  *Prefill* = prompt-eval (prefill) tok/s; *Gen* = generation tok/s; *TTFT* = warm
  time-to-first-token; *Load* = cold model load-to-VRAM; *VRAM* = resident size.
- **Image** — end-to-end via the ComfyUI API at 1024×1024. *Cold* = first gen after
  a checkpoint switch (includes load-to-VRAM); *Warm* = checkpoint resident.
- Scripts: [`ai-lab/bench/`](../ai-lab/bench/) — reproduce with the commands below.

### Language models — `server-nixos`, Radeon 8060S (`gfx1151`)

| Model | Gen tok/s | Prefill tok/s | TTFT (warm) | Cold load | VRAM | GPU |
|-------|----------:|--------------:|------------:|----------:|-----:|:---:|
| `qwen3:30b-a3b` (MoE) | **61.9** | 4548 | 21 ms | 3.8 s | 20.3 GB | 100% |
| `qwen2.5:7b` | 44.6 | 4847 | 23 ms | 3.9 s | 6.3 GB | 100% |
| `qwen2.5vl:7b` | 43.7 | 4355 | 24 ms | 2.7 s | 14.7 GB | 100% |
| `dolphin3:8b` | 41.4 | 4119 | 26 ms | 3.9 s | 7.9 GB | 100% |
| `qwen2.5-coder:32b` | 11.0 | 1224 | 92 ms | 12.6 s | 25.1 GB | 100% |
| `llama3.3:70b` | 5.0 | 456 | 206 ms | 21.4 s | 49.5 GB | 100% |

The MoE result is the takeaway: `qwen3:30b-a3b` is **faster than the 7B/8B dense
models** while carrying 30B-class knowledge, because only ~3B params activate per
token. On this memory-rich, compute-modest iGPU, MoE is the architecture to reach for.

### Embeddings — `server-nixos`

| Model | Embeddings/s |
|-------|-------------:|
| `nomic-embed-text` | 21.4 |
| `bge-m3` | 4.9 |

### Image generation — `workstation-nixos`, RX 9070 XT (`gfx1201`), 1024×1024

| Checkpoint | Steps | Cold | Warm |
|-----------|------:|-----:|-----:|
| `FLUX.1-schnell` (fp8) | 4 | 21.0 s | **6.7 s** |
| `SDXL base 1.0` | 30 | 16.2 s | 8.0 s |
| `Juggernaut-XL v9` | 30 | 12.8 s | 7.7 s |
| `Illustrious-XL v1.0` | 30 | 12.6 s | 7.7 s |

FLUX matches 30-step SDXL warm time in only 4 steps, at noticeably higher quality.

### Reproducing

```bash
# LLM pass (run against the Ollama endpoint; binds to the wg0 IP)
python3 ai-lab/bench/llm_bench.py http://10.100.0.2:11434

# SDXL image pass (on the ComfyUI host)
bash ai-lab/bench/comfy_bench.sh http://127.0.0.1:8188

# FLUX image pass
bash ai-lab/bench/flux_bench.sh http://127.0.0.1:8188
```

## Use cases

- **Conversational inference** — local chat via Ollama (Open WebUI front-end).
- **Coding assistance** — `qwen2.5-coder` for generation and review.
- **Retrieval-augmented generation (RAG)** — `nomic-embed`/`bge-m3` + ChromaDB, grounded Q&A.
- **Multi-model quorum** — N models answer independently and are cross-checked to cut hallucination.
- **Deep research** — SearXNG → fetch → synthesize.
- **Image generation** — ComfyUI SDXL/FLUX pipelines with FaceID and upscaling.
- **Voice pipelines** — STT + Kokoro TTS, streaming, push-to-talk.
- **Game integrations / plugins** — embedding the local LLM + voice stack into games as
  real-time agents; the [Elite Dangerous copilot](../ai-lab/eliteintel/) is the reference
  implementation (local model, on-box STT/TTS, push-to-talk).

## Serving stack

All wg0-only:

- **Ollama** — LLM + embedding server (`gfx1151`).
- **Open WebUI** — chat front-end + inline image gen.
- **ComfyUI** — image generation (a `gfx1151` instance on the server, a `gfx1201`
  render node on the workstation).
- **SearXNG** — private metasearch for the research tools.
- **ChromaDB** — vector store for RAG.
- **ntfy** — self-hosted push-notification hub (`:2586`), the lab's private alert channel.

## Monitoring & operations

The lab self-monitors and pushes alerts to the private ntfy hub (topic `lab-alerts`,
bridged into the desktops' Noctalia notification center) — no cloud. Throughout, the
local LLM only triages/summarizes; severities are assigned deterministically in code.

- **fleet-sentinel** (server, nightly) — fleet health (failed units, disk, ZFS, journal
  errors filtered against `docs/audit/known-states.md`) **plus backup integrity** (each
  auto-snapshot dataset must have recent snapshots). `qwen3` annotates each finding and
  writes the summary. → `/var/lib/fleet-sentinel/latest.md` + ntfy.
- **post-rebuild verifier** (all hosts) — an activation hook checks for failed units
  ~90 s after any rebuild → ntfy. Catches silent post-rebuild regressions.
- **AMD-stack smoke test** (workstation, daily) — a 1-token Ollama gen (`gfx1151`) + a
  tiny ComfyUI gen (`gfx1201`); alerts if either ROCm path breaks after an update.
- **update advisor** (server, weekly) — previews `nix flake update` on a throwaway copy
  of the flake (never switches), then `qwen3` gives a per-input risk briefing.

**Backups** — ZFS auto-snapshots on a dedicated `rpool/storage/git` dataset (the bare
git repos), every 15 min + hourly/daily/weekly/monthly; the sentinel's backup check
guards against them silently stopping. Models/media are excluded (re-downloadable).

## Claude Code MCP tools

A read-only **host-health MCP server** (`ai-lab/mcp/host-health/`, invoked as
`ssh server-nixos host-health-mcp`, loaded via the repo `.mcp.json`) exposes:

| Tool | What it does |
|------|--------------|
| `pool_status` | ZFS pool health, capacity, last scrub |
| `service_status` | systemd service state (key infra services) |
| `journal_errors` | recent journal errors (server) |
| `disk_usage` | ZFS dataset usage |
| `ollama_models` | installed Ollama models |
| `fleet_health` | one-shot health snapshot across all three hosts (uptime, failed units, disk, ZFS, generation) |
| `fleet_service_status` | systemd service state per host |
| `fleet_journal_errors` | recent journal errors per host |
| `backup_status` | ZFS-snapshot backup integrity + last scrub, fleet-wide |
| `flake_status` | days-since-update per flake input |
| `zfs_snapshots` | list a dataset's snapshots (+ recover-a-file hint) |

All read-only. Separately, `lab_quorum` / `lab_rag_query` / `lab_research`
(`ai-lab/api/`) are exposed to Open WebUI as OpenAPI tools.

## Hardware notes / gotchas

The hard-won bits, since AMD APU/RDNA4 inference is still rough terrain:

- **`gfx1151` (Strix Halo iGPU)** — needs the *unstable* `ollama-rocm` (0.24.0, native
  `gfx1151`); stable Ollama crashes during compute even with `HSA_OVERRIDE_GFX_VERSION`.
  All models above run **100% on the GPU**. The usable ceiling is the ~62 GB GTT pool.
- **`gfx1201` (RX 9070 XT, RDNA 4)** — ComfyUI on ROCm 7.2 / PyTorch 2.12. HIP
  impersonates CUDA, so ComfyUI auto-enables two Nvidia-only optimizations (async
  weight offload + pinned host memory) that coredump on `gfx1201` during tiled SD
  upscaling. Launch with `--disable-async-offload --disable-pinned-memory` to fix it.
  FLUX fp8 fits the 16 GB card because the T5 text encoder offloads to system RAM.
