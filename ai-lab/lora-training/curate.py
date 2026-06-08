#!/usr/bin/env python3
"""Curate a raw image tree into a flat curated set.

Drops: unreadable/corrupt files, images whose short side < MIN_SHORT, and exact
duplicates (md5). Survivors are copied with sequential names (img_00001.ext).

Privacy: prints ONLY aggregate counts — never filenames, folder names, or any image
content. Runs inside the trainer container (which has Pillow). Recurses subfolders.

Usage: python3 curate.py <raw_dir> <curated_dir>
"""
import sys, os, hashlib, shutil
from PIL import Image

MIN_SHORT = 768  # SDXL trains at ~1024; drop anything too low-res to learn from
EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    seen = set()
    kept = small = dup = bad = total = 0
    for root, _, files in os.walk(src):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in EXTS:
                continue
            total += 1
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
            kept += 1
            shutil.copy2(p, os.path.join(dst, f"img_{kept:05d}{ext}"))
    print(f"scanned={total} kept={kept} dropped_small={small} "
          f"dropped_dup={dup} dropped_bad={bad}")


if __name__ == "__main__":
    main()
