#!/usr/bin/env bash
# FLUX.1-schnell image-gen benchmark: end-to-end seconds/image (cold + warm).
# 1024x1024, 4 steps (schnell is distilled), cfg 1.0, euler/simple.
#
# Usage:  bash flux_bench.sh [http://127.0.0.1:8188] [workflow.json]
set -u
HOST=${1:-http://127.0.0.1:8188}
WF=${2:-"$(dirname "$0")/flux-schnell-bench.json"}

submit() { # $1=seed -> prompt_id
  local body
  body=$(jq -c --argjson seed "$1" '.["3"].inputs.seed=$seed | {prompt: .}' "$WF")
  curl -s -X POST "$HOST/prompt" -d "$body" | jq -r '.prompt_id'
}
run() { # $1=seed -> seconds
  local t0 t1 id
  t0=$(date +%s%3N)
  id=$(submit "$1")
  { [ -z "$id" ] || [ "$id" = "null" ]; } && { echo "ERR"; return; }
  while [ "$(curl -s "$HOST/history/$id" | jq -r --arg id "$id" 'has($id)')" != "true" ]; do
    sleep 0.25
  done
  t1=$(date +%s%3N)
  awk "BEGIN{printf \"%.2f\", ($t1-$t0)/1000}"
}
echo "checkpoint,cold_s,warm_s (1024x1024, 4 steps, euler/simple)"
echo "flux1-schnell-fp8,$(run 111),$(run 222)"
