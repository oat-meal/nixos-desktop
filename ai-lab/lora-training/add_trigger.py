#!/usr/bin/env python3
"""Prepend the style trigger word to every caption .txt in a directory.

So each caption becomes e.g. "oatstyle, 1girl, standing, ...". Idempotent (won't
double-add). Prints only a count — no captions or filenames.

Usage: python3 add_trigger.py <caption_dir> <trigger_word>
"""
import sys, os

d, trigger = sys.argv[1], sys.argv[2]
n = 0
for f in os.listdir(d):
    if not f.endswith(".txt"):
        continue
    p = os.path.join(d, f)
    with open(p) as fh:
        cap = fh.read().strip()
    if cap.startswith(trigger + ",") or cap == trigger:
        continue
    with open(p, "w") as fh:
        fh.write(f"{trigger}, {cap}" if cap else trigger)
    n += 1
print(f"trigger '{trigger}' prepended to {n} captions")
