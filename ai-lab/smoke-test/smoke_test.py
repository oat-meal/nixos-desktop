#!/usr/bin/env python3
"""AMD ROCm stack smoke test — verify the fragile inference paths still work.

Tiny Ollama generation (gfx1151 LLM tier) + a tiny ComfyUI image gen (gfx1201
render node). If either breaks — e.g. after a flake update regresses ollama-rocm
or the RDNA4 ComfyUI image — it alerts the lab ntfy hub. Meant to run on the
workstation (reaches Ollama over wg0 + ComfyUI on loopback) via a systemd timer.

Env: OLLAMA_HOST_URL, COMFY_URL, SMOKE_MODEL, SMOKE_CKPT, NTFY_URL.
"""
import json
import os
import sys
import time
import urllib.request

OLLAMA = os.environ.get("OLLAMA_HOST_URL", "http://10.100.0.2:11434")
COMFY = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")
MODEL = os.environ.get("SMOKE_MODEL", "qwen2.5:7b")
CKPT = os.environ.get("SMOKE_CKPT", "sd_xl_base_1.0.safetensors")
NTFY = os.environ.get("NTFY_URL", "")


def _post(url, body, timeout):
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def check_ollama():
    """One-token generation — exercises ROCm compute on the LLM tier."""
    try:
        r = _post(OLLAMA + "/api/generate",
                  {"model": MODEL, "prompt": "ping", "stream": False,
                   "options": {"num_predict": 1}}, 90)
        return True if (r.get("response") is not None and r.get("done")) else "no valid response"
    except Exception as e:
        return f"{e}"


def check_comfy():
    """Tiny 512x512 3-step gen — exercises the ROCm image pipeline end-to-end."""
    wf = {
        "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 3, "cfg": 6.0,
              "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0,
              "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "a red circle", "clip": ["4", 1]}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["4", 1]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "PreviewImage", "inputs": {"images": ["8", 0]}},  # temp, not saved to output/
    }
    try:
        r = _post(COMFY + "/prompt", {"prompt": wf}, 20)
        pid = r.get("prompt_id")
        if not pid:
            return "no prompt_id"
        for _ in range(90):
            with urllib.request.urlopen(COMFY + f"/history/{pid}", timeout=10) as h:
                hist = json.load(h)
            if pid in hist:
                st = hist[pid].get("status", {})
                if st.get("status_str") == "error":
                    return "gen errored"
                return True
            time.sleep(2)
        return "timed out"
    except Exception as e:
        return f"{e}"


def main():
    results = {"ollama (gfx1151)": check_ollama(), "comfyui (gfx1201)": check_comfy()}
    ts = time.strftime("%Y-%m-%d %H:%M")
    failed = {k: v for k, v in results.items() if v is not True}
    if not failed:
        print(f"[stack-smoke] {ts} OK — ollama + comfyui healthy")
        return
    msg = "; ".join(f"{k}: {v}" for k, v in failed.items())
    print(f"[stack-smoke] {ts} FAIL — {msg}")
    if NTFY:
        try:
            req = urllib.request.Request(
                NTFY, data=f"AMD stack smoke test FAILED — {msg}".encode(),
                headers={"Title": "Stack smoke test failed", "Priority": "high",
                         "Tags": "rotating_light"})
            urllib.request.urlopen(req, timeout=10)
        except Exception:
            pass
    sys.exit(1)


if __name__ == "__main__":
    main()
