"""
title: World Builder
author: ai-lab
version: 0.1.0
description: Write SillyTavern World Info from chat. The model calls set_world() to turn an established world brief into a lorebook, and add_to_world() to record new canon during play — both land in SillyTavern over its API with no manual export/import. Stays local (wg0).
requirements:
"""

# Open WebUI Tool — paste into Workspace -> Tools -> (+), then enable it for a tool-calling
# model (e.g. qwen2.5:7b) together with the World Weaver / Game Master system prompt.
#
# Flow: the conversation model builds the world with you; when the world is set it calls
# set_world(name, brief) -> this tool asks Ollama (structured output) to expand the brief into
# entries, wraps them in SillyTavern's World Info schema, and POSTs to SillyTavern. During play
# it calls add_to_world(...) to append a single new entry. No files, no import — the book shows
# up in SillyTavern's World Info list, ready to activate.

import json
import urllib.request
import urllib.error
import http.cookiejar

try:
    from pydantic import BaseModel, Field
except ImportError:  # allows standalone self-test without pydantic
    class BaseModel:  # type: ignore
        pass
    def Field(default=None, **_):  # type: ignore
        return default

DEFAULT_ST = "http://10.100.0.2:8002"
DEFAULT_OLLAMA = "http://10.100.0.2:11434"
DEFAULT_MODEL = "qwen2.5:7b"

# Model fills only the creative fields; the schema below is grammar-enforced by Ollama.
GEN_SCHEMA = {
    "type": "object",
    "properties": {
        "entries": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "category": {"type": "string", "enum": ["core", "location", "faction", "character", "item", "lore"]},
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

_GEN_SYSTEM = (
    "You are a worldbuilding assistant. You write vivid but concise lore. Refer to the player "
    "as {{user}}. No markdown, no asterisk stage-directions. Return ONLY the structured data."
)


def _gen_user(brief, count):
    return (
        f"WORLD BRIEF:\n{brief}\n\n"
        f'Produce: exactly 2 "core" entries — the first titled "World Premise" (1-3 sentence '
        f'setting + central hook), the second titled "Tone & Rules" (mood + what is possible or '
        f'forbidden). Then {count} entries across "location"/"faction"/"character"/"item"/"lore", '
        f"each a distinct named element with 2-4 lowercase trigger keys (name + aliases) and 2-4 "
        f"sentences of concrete lore. Do NOT create an entry for {{{{user}}}}. Make elements "
        f"interconnect so it reads as one coherent world."
    )


def _ollama_entries(ollama_url, model, brief, count):
    body = {
        "model": model,
        "messages": [{"role": "system", "content": _GEN_SYSTEM},
                     {"role": "user", "content": _gen_user(brief, count)}],
        "format": GEN_SCHEMA, "stream": False, "options": {"temperature": 0.8},
    }
    req = urllib.request.Request(ollama_url.rstrip("/") + "/api/chat",
                                 data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        content = json.load(r)["message"]["content"]
    items = json.loads(content)["entries"]
    # give core entries canonical titles (the model often lowercases or omits them)
    canonical, seen = ["World Premise", "Tone & Rules"], 0
    for e in items:
        if e.get("category") == "core":
            e["title"] = canonical[seen] if seen < len(canonical) else "Core"
            seen += 1
    return items


def _wrap(uid, category, title, keys, content):
    constant = category == "core"
    entry = dict(ST_ENTRY_DEFAULTS)
    entry.update({
        "uid": uid, "displayIndex": uid,
        "key": [] if constant else [k.strip() for k in keys if k.strip()],
        "comment": (title or "").strip(), "content": (content or "").strip(),
        "constant": constant,
    })
    return entry


def _book_from_items(items):
    entries = {str(i): _wrap(i, e.get("category", "lore"), e.get("title", ""),
                             e.get("keys", []), e.get("content", "")) for i, e in enumerate(items)}
    return {"entries": entries}


# --- SillyTavern API (CSRF + session cookie) ---

def _st_session(st_url):
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    with opener.open(st_url.rstrip("/") + "/csrf-token", timeout=30) as r:
        token = json.load(r)["token"]
    return opener, token


def _st_post(st_url, path, payload):
    opener, token = _st_session(st_url)
    req = urllib.request.Request(st_url.rstrip("/") + path,
                                 data=json.dumps(payload).encode("utf-8"),
                                 headers={"Content-Type": "application/json", "X-CSRF-Token": token})
    with opener.open(req, timeout=60) as r:
        return r.read().decode()


def _create_world(st_url, name, book):
    return _st_post(st_url, "/api/worldinfo/edit", {"name": name, "data": book})


def _get_world(st_url, name):
    try:
        return json.loads(_st_post(st_url, "/api/worldinfo/get", {"name": name}))
    except (urllib.error.HTTPError, json.JSONDecodeError):
        return None


class Tools:
    class Valves(BaseModel):
        sillytavern_url: str = Field(default=DEFAULT_ST, description="SillyTavern base URL (wg0)")
        ollama_url: str = Field(default=DEFAULT_OLLAMA, description="Ollama base URL (wg0)")
        gen_model: str = Field(default=DEFAULT_MODEL, description="Model used to expand the brief into entries")

    def __init__(self):
        self.valves = self.Valves()

    def set_world(self, name: str, brief: str, count: int = 10) -> str:
        """
        Create (or replace) a SillyTavern World Info lorebook from a world brief. Call this once
        the world's premise, tone, and key elements are established in the conversation.
        :param name: short name for the world / lorebook (e.g. "Aethelgard")
        :param brief: a few paragraphs describing the world — premise, tone, rules, key places, factions, characters
        :param count: number of keyword-triggered detail entries to generate (default 10)
        """
        try:
            items = _ollama_entries(self.valves.ollama_url, self.valves.gen_model, brief, count)
            book = _book_from_items(items)
            _create_world(self.valves.sillytavern_url, name, book)
        except Exception as e:  # noqa: BLE001 — surface any failure to the model/user
            return f"Failed to create World Info '{name}': {e}"
        n = len(book["entries"])
        return (f"Created World Info '{name}' with {n} entries. In SillyTavern open the World Info "
                f"(globe) panel, select '{name}', and activate it (or bind it to your group).")

    def add_to_world(self, name: str, title: str, keys: str, content: str, constant: bool = False) -> str:
        """
        Add one entry to an existing World Info lorebook. Use during play when new canon appears
        (a place, person, faction, or fact worth keeping).
        :param name: the lorebook to add to (must already exist)
        :param title: short label for the entry (the element's name)
        :param keys: comma-separated trigger words (the name plus aliases)
        :param content: the lore text (2-4 sentences)
        :param constant: true = always active; false (default) = triggered when a key appears
        """
        book = _get_world(self.valves.sillytavern_url, name)
        if book is None or "entries" not in book:
            return f"World Info '{name}' not found — create it first with set_world()."
        entries = book["entries"]
        uid = max((int(k) for k in entries.keys()), default=-1) + 1
        key_list = [k.strip() for k in keys.split(",") if k.strip()]
        entries[str(uid)] = _wrap(uid, "core" if constant else "lore", title, key_list, content)
        try:
            _create_world(self.valves.sillytavern_url, name, book)
        except Exception as e:  # noqa: BLE001
            return f"Failed to add '{title}' to '{name}': {e}"
        return f"Added '{title}' to World Info '{name}' ({'always-on' if constant else 'keyword: ' + ', '.join(key_list)})."


if __name__ == "__main__":
    # Self-test: build a tiny world, post it, read it back, add an entry, then delete. Usage:
    #   python3 worldbuilder_tool.py <st_url> <ollama_url> <model>
    import sys
    st = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ST
    oll = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OLLAMA
    mdl = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_MODEL
    name = "_plugintest"
    print("generating entries...")
    items = _ollama_entries(oll, mdl, "A dying-winter kingdom of court intrigue; an heirless king fades while rival houses circle. Magic is feared and outlawed.", 3)
    book = _book_from_items(items)
    print(f"  built {len(book['entries'])} entries")
    print("creating world via ST API:", _create_world(st, name, book))
    got = _get_world(st, name)
    print(f"  read back: {len(got['entries'])} entries; titles =", [e["comment"] for e in got["entries"].values()])
    # add one entry
    entries = got["entries"]
    uid = max(int(k) for k in entries) + 1
    entries[str(uid)] = _wrap(uid, "lore", "The Frostgate", ["frostgate"], "An ancient sealed gate in the northern wall.")
    _create_world(st, name, got)
    print("  after add_to_world:", len(_get_world(st, name)["entries"]), "entries")
    print("cleanup delete:", _st_post(st, "/api/worldinfo/delete", {"name": name}))
