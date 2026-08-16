"""
title: ComfyUI Image Generation
author: ai-lab
version: 0.1.0
description: Generate images on the local ComfyUI server. The model calls this automatically when the user asks for an image, so no manual toggle is needed.
requirements:
"""

# Open WebUI Tool — paste into Workspace -> Tools -> (+). Then enable it for your
# chat model and use a tool-calling model (qwen2.5). Asking for an image will make
# the model call generate_image(), which renders the result inline.
#
# Renders on the WORKSTATION node (10.100.0.1:8188, RX 9070 XT / gfx1201) — faster than
# the server's gfx1151 instance, and it keeps image gen off the GPU Ollama is using.
# The server instance (10.100.0.2:8188) stays up as a fallback: point the comfyui_url
# valve at it if the workstation is down or mid-rebuild.
#
# Uses the same 7-node SDXL text2img graph already verified on the server. The image is
# returned as a URL to ComfyUI's /view endpoint — your browser runs on the workstation
# and fetches it directly, so nothing large is embedded in the chat.
#
# NOTE: this file is the SOURCE you paste into Open WebUI. The live value lives in the
# Open WebUI DB (/var/lib/open-webui/webui.db), NOT in nix — editing this default does
# not change a tool that is already installed. Update the valve in the UI as well:
# Workspace -> Tools -> ComfyUI Image Generation -> comfyui_url.

import asyncio
import json
import random
import urllib.request
from urllib.parse import quote

from pydantic import BaseModel, Field


class Tools:
    class Valves(BaseModel):
        comfyui_url: str = Field(
            default="http://10.100.0.1:8188",
            description="ComfyUI base URL (wg0). Workstation gfx1201 render node; "
            "fallback is the server instance at http://10.100.0.2:8188",
        )
        checkpoint: str = Field(
            default="Illustrious-XL-v1.0.safetensors",
            description="Checkpoint filename in ComfyUI models/checkpoints",
        )
        width: int = Field(default=832, description="Image width")
        height: int = Field(default=1216, description="Image height")
        steps: int = Field(default=30, description="Sampling steps")
        cfg: float = Field(default=6.5, description="CFG scale")
        sampler: str = Field(default="dpmpp_2m", description="Sampler")
        scheduler: str = Field(default="karras", description="Scheduler")
        negative: str = Field(
            default="worst quality, low quality, bad anatomy, deformed hands, extra fingers, extra toes",
            description="Negative prompt applied to every image",
        )
        timeout: int = Field(default=180, description="Max seconds to wait for a render")

    def __init__(self):
        self.valves = self.Valves()

    async def generate_image(self, prompt: str, __event_emitter__=None) -> str:
        """
        Generate an image from a text description using the local ComfyUI server.
        Call this whenever the user asks to create, draw, generate, make, render, or
        show an image, picture, photo, art, or illustration. Pass a detailed visual
        description of what to depict.

        :param prompt: A detailed description of the image to generate.
        :return: A short status note. The image itself is displayed inline.
        """
        v = self.valves

        async def status(msg, done=False):
            if __event_emitter__:
                await __event_emitter__(
                    {"type": "status", "data": {"description": msg, "done": done}}
                )

        await status("Generating image…")

        seed = random.randint(0, 2**31 - 1)
        workflow = {
            "3": {"class_type": "KSampler", "inputs": {
                "seed": seed, "steps": v.steps, "cfg": v.cfg, "sampler_name": v.sampler,
                "scheduler": v.scheduler, "denoise": 1.0, "model": ["4", 0],
                "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
            "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": v.checkpoint}},
            "5": {"class_type": "EmptyLatentImage", "inputs": {
                "width": v.width, "height": v.height, "batch_size": 1}},
            "6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
            "7": {"class_type": "CLIPTextEncode", "inputs": {"text": v.negative, "clip": ["4", 1]}},
            "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
            "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "owui-tool", "images": ["8", 0]}},
        }

        try:
            data = json.dumps({"prompt": workflow}).encode()
            req = urllib.request.Request(
                v.comfyui_url + "/prompt", data=data,
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                pid = json.load(r)["prompt_id"]
        except Exception as e:
            await status(f"Failed to start: {e}", done=True)
            return f"Image generation failed to start: {e}"

        elapsed = 0
        img = None
        while elapsed < v.timeout:
            await asyncio.sleep(2)
            elapsed += 2
            try:
                with urllib.request.urlopen(v.comfyui_url + "/history/" + pid, timeout=15) as r:
                    hist = json.load(r)
            except Exception:
                continue
            entry = hist.get(pid)
            if not entry:
                continue
            outs = entry.get("outputs", {})
            images = [im for o in outs.values() if "images" in o for im in o["images"]]
            if images:
                img = images[0]
                break
            msgs = entry.get("status", {}).get("messages", [])
            if any(m and m[0] == "execution_error" for m in msgs):
                await status("ComfyUI execution error", done=True)
                return "ComfyUI reported an execution error while rendering."

        if not img:
            await status("Timed out", done=True)
            return "Image generation timed out."

        url = (
            f"{v.comfyui_url}/view?filename={quote(img['filename'])}"
            f"&subfolder={quote(img.get('subfolder', ''))}&type=output"
        )
        markdown = f"\n![{prompt[:60]}]({url})\n"

        if __event_emitter__:
            await __event_emitter__({"type": "message", "data": {"content": markdown}})
            await status("Image generated.", done=True)
            return (
                "The image has been generated and is already shown to the user above. "
                "Do not describe or restate it; just briefly acknowledge."
            )
        # No emitter available — return the markdown so it still renders.
        return markdown
