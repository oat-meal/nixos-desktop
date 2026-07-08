#!/usr/bin/env bash
# ComfyUI SDXL image-gen benchmark: end-to-end seconds/image per checkpoint.
# Cold = first gen after checkpoint switch (includes load-to-VRAM);
# warm = second gen with checkpoint resident. 1024x1024, fixed steps/seed/prompt.
#
# Usage:  bash comfy_bench.sh [http://127.0.0.1:8188] [workflow.json]
set -u
HOST=${1:-http://127.0.0.1:8188}
WF=${2:-"$(dirname "$0")/../comfyui/workflows/openwebui-text2img.json"}
CKPTS=("sd_xl_base_1.0.safetensors" "Juggernaut-XL_v9.safetensors" "Illustrious-XL-v1.0.safetensors")
STEPS=30; W=1024; H=1024
POS="a detailed landscape photograph of a mountain lake at sunrise, mist, reflections"
NEG="blurry, low quality, watermark, text"

submit() { # $1=ckpt $2=seed -> prompt_id
  local body
  body=$(jq -c --arg c "$1" --argjson seed "$2" --argjson steps "$STEPS" \
    --argjson w "$W" --argjson h "$H" --arg pos "$POS" --arg neg "$NEG" \
    '.["4"].inputs.ckpt_name=$c
     | .["3"].inputs.seed=$seed | .["3"].inputs.steps=$steps
     | .["5"].inputs.width=$w | .["5"].inputs.height=$h
     | .["6"].inputs.text=$pos | .["7"].inputs.text=$neg
     | {prompt: .}' "$WF")
  curl -s -X POST "$HOST/prompt" -d "$body" | jq -r '.prompt_id'
}
run() { # $1=ckpt $2=seed -> seconds
  local t0 t1 id
  t0=$(date +%s%3N)
  id=$(submit "$1" "$2")
  { [ -z "$id" ] || [ "$id" = "null" ]; } && { echo "ERR"; return; }
  while [ "$(curl -s "$HOST/history/$id" | jq -r --arg id "$id" 'has($id)')" != "true" ]; do
    sleep 0.25
  done
  t1=$(date +%s%3N)
  awk "BEGIN{printf \"%.2f\", ($t1-$t0)/1000}"
}
echo "checkpoint,cold_s,warm_s (1024x1024, ${STEPS} steps, dpmpp_2m/karras)"
for c in "${CKPTS[@]}"; do
  echo "${c%.safetensors},$(run "$c" 111),$(run "$c" 222)"
done
