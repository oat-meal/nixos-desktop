#!/usr/bin/env bash
# Train the SDXL style LoRA with kohya. GPU access comes from the podman run flags
# (--device kfd/dri, groups, HSA_OVERRIDE). Outputs to /data/output.
set -e

accelerate launch --num_processes 1 --mixed_precision bf16 \
  /opt/sd-scripts/sdxl_train_network.py \
  --config_file /config/config.toml \
  --dataset_config /config/dataset.toml
