#!/usr/bin/env python3
"""lab-lorebook — draft a SillyTavern World Info lorebook with a LOCAL model.

Privacy: everything runs against the home Ollama over wg0 — your worldbuilding never
leaves the lab (no public AI tools). Stdlib only, no deps.

Division of labour: the model writes the *content* (premise, factions, places, people);
this script enforces the SillyTavern *schema*, so the output is always a valid, importable
World Info JSON — even with a small 7B/8B model. Uses Ollama structured outputs (the model
is constrained to a JSON schema) so it can't emit malformed JSON.

Examples:
  # generate on the server, write straight into your private lab-content repo on this host:
  ssh server-nixos python3 /etc/nixos/ai-lab/lorebook/lorebook.py \
      --world "A dying-winter kingdom of court intrigue; the heirless king is fading." \
      --count 8 --model dolphin3:8b \
      > ~/Documents/lab-content/sillytavern/worlds/aethelgard.json

  # longer brief from a file, custom model:
  ssh server-nixos python3 /etc/nixos/ai-lab/lorebook/lorebook.py \
      --world-file - --model qwen2.5-coder:32b < my-brief.txt > out.json

Then import out.json in SillyTavern: globe icon -> Import -> activate it.
"""
import argparse
import json
import sys
import urllib.request
import urllib.error

DEFAULT_HOST = "http://10.100.0.2:11434"
DEFAULT_MODEL = "dolphin3:8b"

# Schema we force the model to emit (Ollama structured outputs). The model only fills the
# creative fields; everything structural is added by wrap_entry() below.
GEN_SCHEMA = {
    "type": "object",
    "properties": {
        "entries": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": ["core", "location", "faction", "character", "item", "lore"],
                    },
                    "title": {"type": "string"},
                    "keys": {"type": "array", "items": {"type": "string"}},
                    "content": {"type": "string"},
                },
                "required": ["category", "title", "keys", "content"],
            },
        }
    },
    "required": ["entries"],
}

# Full SillyTavern World Info entry — defaults for every field; wrap_entry overrides a few.
ST_ENTRY_DEFAULTS = {
    "uid": 0, "key": [], "keysecondary": [], "comment": "", "content": "",
    "constant": False, "vectorized": False, "selective": True, "selectiveLogic": 0,
    "addMemo": True, "order": 100, "position": 0, "disable": False,
    "excludeRecursion": False, "preventRecursion": False, "delayUntilRecursion": False,
    "probability": 100, "useProbability": True, "depth": 4, "group": "",
    "groupOverride": False, "groupWeight": 100, "scanDepth": None, "caseSensitive": None,
    "matchWholeWords": None, "useGroupScoring": None, "automationId": "", "role": None,
    "sticky": 0, "cooldown": 0, "delay": 0, "displayIndex": 0,
}

SYSTEM_PROMPT = (
    "You are a worldbuilding assistant helping an author draft a private interactive "
    "roleplay setting. You write vivid but concise lore. Refer to the player character as "
    "{{user}}. Do not use markdown, headings, or asterisk stage-directions — plain prose "
    "only. Return ONLY the structured data requested."
)


def build_user_prompt(world, count):
    return (
        f"WORLD BRIEF:\n{world}\n\n"
        f"Produce worldbuilding entries for this setting:\n"
        f'- Exactly 2 entries with category "core": one a 1-3 sentence PREMISE (the setting '
        f"plus the central situation/hook), and one the TONE & RULES (mood, plus what is "
        f"possible or forbidden in this world). Core entries are always-on — keep them short.\n"
        f'- {count} more entries across categories "location", "faction", "character", '
        f'"item" (and "lore" for concepts). Each is a distinct, named element of the world.\n\n'
        f"For every entry provide:\n"
        f"- title: a short label (the element's name)\n"
        f"- keys: 2-4 trigger words a player might type that should surface this entry "
        f"(include the proper name and common aliases). For core entries use an empty list.\n"
        f"- content: 2-4 sentences of concrete lore — name people and places, note why it "
        f"matters or a hook, use {{{{user}}}} where relevant.\n"
        f"- category: one of core/location/faction/character/item/lore\n\n"
        f"Make the elements interconnect (shared names, conflicts, stakes) so they read as "
        f"one coherent world."
    )


def ollama_chat(host, model, system, user, schema, temperature):
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "format": schema,
        "stream": False,
        "options": {"temperature": temperature},
    }
    req = urllib.request.Request(
        host.rstrip("/") + "/api/chat",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=600) as r:
        resp = json.load(r)
    return resp["message"]["content"]


def wrap_entry(uid, e):
    """Turn a model {category,title,keys,content} into a full ST World Info entry."""
    constant = e.get("category", "lore") == "core"
    entry = dict(ST_ENTRY_DEFAULTS)
    entry.update({
        "uid": uid,
        "key": [] if constant else [k for k in e.get("keys", []) if k.strip()],
        "comment": e.get("title", "").strip(),
        "content": e.get("content", "").strip(),
        "constant": constant,
        "displayIndex": uid,
    })
    return entry


def main():
    ap = argparse.ArgumentParser(description="Draft a SillyTavern World Info lorebook with a local model.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--world", "-w", help="World brief / premise (a few sentences).")
    src.add_argument("--world-file", help="Read the world brief from a file ('-' = stdin).")
    ap.add_argument("--count", "-n", type=int, default=8, help="Triggered entries to generate (default 8; 2 core always added).")
    ap.add_argument("--model", "-m", default=DEFAULT_MODEL, help=f"Ollama model (default {DEFAULT_MODEL}).")
    ap.add_argument("--host", default=DEFAULT_HOST, help=f"Ollama base URL (default {DEFAULT_HOST}).")
    ap.add_argument("--temperature", "-t", type=float, default=0.8, help="Sampling temperature (default 0.8).")
    ap.add_argument("--output", "-o", default="-", help="Output file ('-' = stdout, default).")
    args = ap.parse_args()

    if args.world_file:
        world = (sys.stdin.read() if args.world_file == "-" else open(args.world_file).read()).strip()
    else:
        world = args.world.strip()
    if not world:
        sys.exit("error: empty world brief.")

    try:
        raw = ollama_chat(args.host, args.model, SYSTEM_PROMPT,
                          build_user_prompt(world, args.count), GEN_SCHEMA, args.temperature)
    except urllib.error.URLError as e:
        sys.exit(f"error: cannot reach Ollama at {args.host} ({e}). Is it up on wg0?")

    try:
        gen = json.loads(raw)
        items = gen["entries"]
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        sys.exit(f"error: model returned unusable output ({e}). Try a bigger model (e.g. qwen2.5-coder:32b) or rerun.")

    entries = {str(i): wrap_entry(i, e) for i, e in enumerate(items)}
    book = json.dumps({"entries": entries}, indent=2, ensure_ascii=False)

    if args.output == "-":
        print(book)
    else:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(book + "\n")
        n_core = sum(1 for e in entries.values() if e["constant"])
        print(f"wrote {args.output}: {len(entries)} entries ({n_core} core, {len(entries)-n_core} triggered)", file=sys.stderr)


if __name__ == "__main__":
    main()
