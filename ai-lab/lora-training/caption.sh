#!/usr/bin/env bash
# Auto-caption /data/curated with the WD14 tagger (Danbooru tags, ideal for anime),
# then prepend the 'oatstyle' trigger to every caption. Run inside the trainer
# container. CPU onnxruntime — captioning ~6k images takes tens of minutes (once).
set -e

python3 /opt/sd-scripts/finetune/tag_images_by_wd14_tagger.py \
  --onnx \
  --remove_underscore \
  --batch_size 8 \
  --caption_extension .txt \
  --repo_id SmilingWolf/wd-v1-4-moat-tagger-v2 \
  /data/curated

python3 /config/add_trigger.py /data/curated oatstyle
