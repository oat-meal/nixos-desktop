# lab-lorebook

Draft a **SillyTavern World Info lorebook** with a **local** model. You write the lore framing;
the model fills in the world; the script emits a complete, valid, importable JSON. Your
worldbuilding never leaves the lab (Ollama over wg0 — no public AI tools).

The model only writes the *content*; the script enforces the SillyTavern *schema* via Ollama
structured outputs, so the output is always importable even with a small 7B/8B model.

## Use

Run it on the server (has python3), redirect the JSON into your private `lab-content` repo on
this host, then import once in SillyTavern:

```
ssh server-nixos python3 /etc/nixos/ai-lab/lorebook/lorebook.py \
    --world "A dying-winter kingdom of court intrigue; the heirless king is fading and rival houses circle the throne. Low magic, feared and outlawed. Tone: tense, sharp, dangerous." \
    --count 8 --model dolphin3:8b \
    > ~/Documents/lab-content/sillytavern/worlds/myworld.json
```

Then: SillyTavern → globe icon (World Info) → **Import** → pick `myworld.json` → activate it
(set as an Active World, or bind it to your group).

A longer brief from a file:

```
ssh server-nixos python3 /etc/nixos/ai-lab/lorebook/lorebook.py --world-file - --count 12 \
    < my-brief.txt > ~/Documents/lab-content/sillytavern/worlds/myworld.json
```

## Options

| Flag | Default | Meaning |
|---|---|---|
| `--world` / `-w` | — | Your lore framing / premise (a few sentences). |
| `--world-file` | — | Read the brief from a file (`-` = stdin). |
| `--count` / `-n` | 8 | Triggered entries to generate (2 always-on "core" entries are added automatically). |
| `--model` / `-m` | `dolphin3:8b` | Ollama model. Use `qwen2.5-coder:32b` for the most reliable JSON. |
| `--temperature` / `-t` | 0.8 | Higher = more inventive. |
| `--output` / `-o` | `-` (stdout) | Write to a file instead of stdout. |

## What you get

Two **core** entries (constant / always-on): a Premise and a Tone & Rules. Then N **triggered**
entries (locations, factions, off-screen characters, items) that load only when their keywords
appear in chat — so the world can be large without filling the context window. Re-run to
regenerate; tweak the brief to steer it.
