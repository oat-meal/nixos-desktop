#!/usr/bin/env python3
"""Curate a raw image tree into a balanced, deduped, flat curated set.

Within each immediate subfolder: drop unreadable/too-small/exact-duplicate images,
then keep up to MAX_PER_FOLDER (random). Pool across all folders and cap to TARGET
total. This balances coverage across the pose subfolders and trims a large set down
to a trainable size for a STYLE LoRA (which wants a few hundred good images, not
thousands).

Privacy: prints ONLY aggregate counts — never filenames or folder names. Runs inside
the trainer container (which has Pillow). Recurses subfolders; dedup is global (md5).

Usage: python3 curate.py <raw_dir> <curated_dir> [target_total] [max_per_folder]
Defaults: target_total=800, max_per_folder=3
"""
import sys, os, hashlib, shutil, random
from PIL import Image

MIN_SHORT = 768  # drop anything too low-res to learn from at SDXL 1024
EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
random.seed(42)  # reproducible sampling


def main():
    src, dst = sys.argv[1], sys.argv[2]
    target = int(sys.argv[3]) if len(sys.argv) > 3 else 800
    per_folder = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    os.makedirs(dst, exist_ok=True)

    seen = set()
    scanned = small = dup = bad = 0
    groups = {}  # dirpath -> [valid paths]

    for root, _, files in os.walk(src):
        for f in files:
            if os.path.splitext(f)[1].lower() not in EXTS:
                continue
            scanned += 1
            p = os.path.join(root, f)
            try:
                with open(p, "rb") as fh:
                    h = hashlib.md5(fh.read()).hexdigest()
                if h in seen:
                    dup += 1
                    continue
                with Image.open(p) as im:
                    w, hh = im.size
                if min(w, hh) < MIN_SHORT:
                    small += 1
                    continue
            except Exception:
                bad += 1
                continue
            seen.add(h)
            groups.setdefault(root, []).append(p)

    valid = sum(len(v) for v in groups.values())
    selected = []
    for paths in groups.values():
        random.shuffle(paths)
        selected.extend(paths[:per_folder])
    random.shuffle(selected)
    if len(selected) > target:
        selected = selected[:target]

    for i, p in enumerate(selected, 1):
        ext = os.path.splitext(p)[1].lower()
        shutil.copy2(p, os.path.join(dst, f"img_{i:05d}{ext}"))

    print(f"scanned={scanned} valid_after_filter={valid} groups={len(groups)} "
          f"final_kept={len(selected)} (target={target}, max_per_folder={per_folder}) "
          f"dropped_small={small} dropped_dup={dup} dropped_bad={bad}")


if __name__ == "__main__":
    main()
