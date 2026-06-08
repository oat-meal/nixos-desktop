#!/usr/bin/env python3
"""Flatten / curate a raw image tree into a flat dir for kohya (which doesn't recurse
subfolders). Two modes:

  * target == 0  -> KEEP-ALL: flatten every readable image, no dedup, no resolution
                    filter, no sampling. Only corrupt/unreadable files are skipped.
  * target  > 0  -> BALANCED SAMPLE: dedup (md5) + drop too-small, then keep up to
                    max_per_folder per subfolder, capped to target total.

Privacy: prints ONLY aggregate counts — never filenames or folder names. Runs inside
the trainer container (has Pillow). Recurses subfolders.

Usage: python3 curate.py <raw_dir> <curated_dir> [target_total] [max_per_folder]
Defaults: target_total=800, max_per_folder=3.  Use target 0 to keep everything.
"""
import sys, os, hashlib, shutil, random
from PIL import Image

MIN_SHORT = 768
EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
random.seed(42)


def keep_all(src, dst):
    os.makedirs(dst, exist_ok=True)
    scanned = bad = kept = 0
    for root, _, files in os.walk(src):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in EXTS:
                continue
            scanned += 1
            p = os.path.join(root, f)
            try:
                with Image.open(p) as im:
                    im.size  # readable check
            except Exception:
                bad += 1
                continue
            kept += 1
            shutil.copy2(p, os.path.join(dst, f"img_{kept:05d}{ext}"))
    print(f"mode=keep-all scanned={scanned} kept={kept} dropped_bad={bad}")


def balanced(src, dst, target, per_folder):
    os.makedirs(dst, exist_ok=True)
    seen = set()
    scanned = small = dup = bad = 0
    groups = {}
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
    print(f"mode=balanced scanned={scanned} valid_after_filter={valid} groups={len(groups)} "
          f"final_kept={len(selected)} (target={target}, max_per_folder={per_folder}) "
          f"dropped_small={small} dropped_dup={dup} dropped_bad={bad}")


def main():
    src, dst = sys.argv[1], sys.argv[2]
    target = int(sys.argv[3]) if len(sys.argv) > 3 else 800
    per_folder = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    if target == 0:
        keep_all(src, dst)
    else:
        balanced(src, dst, target, per_folder)


if __name__ == "__main__":
    main()
