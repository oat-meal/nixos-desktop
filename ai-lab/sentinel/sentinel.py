#!/usr/bin/env python3
"""Fleet Health Sentinel — collect wg0 fleet health, triage it, emit a
severity-ranked report. READ-ONLY: it only inspects and reports; it never
changes anything. Meant to run on the server via a systemd timer.

Design: severities are assigned DETERMINISTICALLY in code (LLMs are unreliable at
numeric threshold comparisons). A local LLM is used only for what it is good at —
dropping findings explained by known-states, writing a summary, and suggesting a
read-only diagnostic command per finding. When there are no candidate findings, the
LLM is skipped entirely.

Collection mirrors ai-lab/mcp/host-health/server.py fleet_health, duplicated here
so the sentinel stays stdlib-only (no MCP dependency).

Env: OLLAMA_HOST_URL, SENTINEL_MODEL, KNOWN_STATES, SENTINEL_REPORT, NTFY_URL.
"""
import json
import os
import re
import subprocess
import urllib.request
from datetime import datetime

HOSTS = {"server": None, "workstation": "10.100.0.1", "laptop": "10.100.0.3"}
SYS_PATH = "/run/current-system/sw/bin"
OLLAMA = os.environ.get("OLLAMA_HOST_URL", "http://10.100.0.2:11434")
MODEL = os.environ.get("SENTINEL_MODEL", "qwen3:30b-a3b")
KNOWN_STATES = os.environ.get("KNOWN_STATES", "/etc/nixos/docs/audit/known-states.md")
REPORT = os.environ.get("SENTINEL_REPORT", "/var/lib/fleet-sentinel/latest.md")
NTFY = os.environ.get("NTFY_URL", "")
DISK_WARN, DISK_CRIT = 85, 95
_ESC = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?]*[ -/]*[@-~]")


def _clean(s: str) -> str:
    return _ESC.sub("", s)


def run_on(ip, shell_cmd: str, timeout: int = 12) -> str:
    """Run locally (ip is None) or on a remote wg0 host via ssh (key-only)."""
    full = f"export PATH={SYS_PATH}:$PATH; {shell_cmd}"
    if ip is None:
        argv = ["sh", "-c", full]
    else:
        argv = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
                "-o", "StrictHostKeyChecking=accept-new", f"oat@{ip}", full]
        timeout += 5
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return _clean(r.stdout.strip() or r.stderr.strip())
    except subprocess.TimeoutExpired:
        return "ERROR: timed out"


def collect() -> dict:
    # @@@ markers (not ===): remote login shell is zsh, whose = expansion breaks ===X===.
    script = (
        "echo @@@HOST@@@; hostname; "
        "echo @@@UP@@@; awk '{s=$1; printf \"%dd %dh %dm\\n\", s/86400, s%86400/3600, s%3600/60}' /proc/uptime 2>/dev/null; "
        "echo @@@FAILED@@@; systemctl --failed --no-legend --no-pager 2>/dev/null; "
        "echo @@@DISK@@@; df -h --output=target,pcent / /storage 2>/dev/null | tail -n +2; "
        "echo @@@ZFS@@@; zpool list -H -o name,cap,health 2>/dev/null; "
        "echo @@@GEN@@@; readlink -f /run/current-system 2>/dev/null | sed 's#.*/##'"
    )
    out = {}
    for h, ip in HOSTS.items():
        raw = run_on(ip, script)
        low = raw.lower()
        if raw.startswith("ERROR") or any(x in low for x in (
                "verification failed", "timed out", "refused", "no route",
                "could not resolve", "permission denied")):
            out[h] = {"reachable": False, "detail": raw[:200]}
            continue
        secs, cur = {}, None
        for line in raw.splitlines():
            m = re.match(r"^@@@(\w+)@@@$", line.strip())
            if m:
                cur = m.group(1)
                secs[cur] = []
            elif cur is not None:
                secs[cur].append(line)

        def first(key):
            return next((x.strip() for x in secs.get(key, []) if x.strip()), "")

        failed = [l.strip() for l in secs.get("FAILED", []) if l.strip()]
        out[h] = {
            "reachable": True,
            "hostname": first("HOST"),
            "uptime": first("UP"),
            "failed_count": len(failed),
            "failed_units": failed,
            "disk": [l.strip() for l in secs.get("DISK", []) if l.strip()],
            "zfs": [l.strip() for l in secs.get("ZFS", []) if l.strip()],
            "generation": first("GEN"),
        }
    return out


def _pct(token: str) -> int | None:
    try:
        return int(token.rstrip("%"))
    except ValueError:
        return None


def analyze(health: dict) -> list:
    """Deterministic candidate findings with correct severities (no LLM)."""
    findings = []

    def add(host, sev, text):
        findings.append({"host": host, "severity": sev, "finding": text})

    for h, v in health.items():
        if not v.get("reachable", False):
            if h == "laptop":
                continue  # expected — the laptop powers off
            add(h, "critical", f"host unreachable over wg0 ({v.get('detail', '')[:80]})")
            continue
        for u in v.get("failed_units", []):
            add(h, "warning", f"failed systemd unit: {u}")
        for d in v.get("disk", []):
            parts = d.split()
            if len(parts) >= 2 and (pct := _pct(parts[-1])) is not None:
                if pct > DISK_CRIT:
                    add(h, "critical", f"disk {parts[0]} at {pct}% used")
                elif pct > DISK_WARN:
                    add(h, "warning", f"disk {parts[0]} at {pct}% used")
        for z in v.get("zfs", []):
            parts = z.split()
            if len(parts) >= 3:
                name, cap, hlth = parts[0], _pct(parts[1]), parts[2].upper()
                if hlth != "ONLINE":
                    add(h, "critical", f"ZFS pool {name} health={parts[2]}")
                elif cap is not None and cap > DISK_CRIT:
                    add(h, "critical", f"ZFS pool {name} at {cap}% capacity")
                elif cap is not None and cap > DISK_WARN:
                    add(h, "warning", f"ZFS pool {name} at {cap}% capacity")
    return findings


ENRICH_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "actions": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["summary", "actions"],
}

ENRICH_SYSTEM = """You are a site-reliability engineer for a personal NixOS home lab (hosts: \
server, workstation, laptop; private WireGuard mesh). You are given a JSON array of FINDINGS that \
deterministic checks already classified by severity. You must NOT re-classify, add, or remove any \
finding — the list is authoritative.

Return:
- `actions`: an array with EXACTLY one entry per finding, in the same order. actions[i] is a single \
concrete READ-ONLY diagnostic command to investigate findings[i] (a command to inspect only; never \
destructive or state-changing). If a finding clearly matches an expected KNOWN STATE below, still \
give an action but prefix it with "(likely expected) ".
- `summary`: one sentence on the fleet's overall health.

KNOWN STATES (expected anomalies):
{known_states}
"""


def enrich(candidates: list) -> dict:
    """LLM: drop known-state matches, add read-only actions, write a summary."""
    try:
        known = open(KNOWN_STATES).read()
    except OSError:
        known = "(known-states file not found)"
    body = {
        "model": MODEL, "stream": False, "think": False,
        "format": ENRICH_SCHEMA, "options": {"temperature": 0.1},
        "messages": [
            {"role": "system", "content": ENRICH_SYSTEM.format(known_states=known)},
            {"role": "user", "content": "Candidate findings:\n" + json.dumps(candidates, indent=2)},
        ],
    }
    req = urllib.request.Request(
        OLLAMA + "/api/chat", data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        resp = json.load(r)
    return json.loads(resp["message"]["content"])


def _overall(findings: list) -> str:
    sevs = {f.get("severity") for f in findings}
    if "critical" in sevs:
        return "critical"
    if "warning" in sevs:
        return "warnings"
    return "healthy"


_SEV_ORDER = {"critical": 0, "warning": 1, "info": 2}


def render(health: dict, verdict: dict, ts: str) -> str:
    status = verdict.get("overall_status", "unknown")
    lines = [f"# Fleet Health — {ts}", "",
             f"**Status:** {status.upper()}", "",
             verdict.get("summary", ""), ""]
    findings = verdict.get("findings", [])
    if findings:
        lines += ["## Findings", "",
                  "| Host | Severity | Finding | Suggested check |",
                  "|------|----------|---------|-----------------|"]
        for f in sorted(findings, key=lambda x: _SEV_ORDER.get(x.get("severity"), 3)):
            fnd = f.get("finding", "").replace("|", "\\|")
            act = f.get("suggested_action", "").replace("|", "\\|")
            lines.append(f"| {f.get('host', '?')} | {f.get('severity', '?')} | {fnd} | {act} |")
        lines.append("")
    lines += ["## Raw snapshot", "", "```json", json.dumps(health, indent=2), "```", ""]
    return "\n".join(lines)


def main():
    ts = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    health = collect()
    candidates = analyze(health)

    if not candidates:
        verdict = {"overall_status": "healthy",
                   "summary": "All hosts reachable; no disk, ZFS, or unit issues.",
                   "findings": []}
    else:
        # Deterministic findings are authoritative; the LLM only annotates them
        # (one diagnostic action each) and writes a summary — it cannot add/drop.
        summary = ""
        try:
            enriched = enrich(candidates)
            actions = enriched.get("actions", [])
            summary = enriched.get("summary", "")
        except Exception as e:  # degrade gracefully — never crash the timer
            actions, summary = [], f"(LLM enrichment failed: {e})"
        for i, c in enumerate(candidates):
            c["suggested_action"] = actions[i] if i < len(actions) else ""
        verdict = {"overall_status": _overall(candidates),
                   "summary": summary, "findings": candidates}

    report = render(health, verdict, ts)
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    with open(REPORT, "w") as f:
        f.write(report)

    n = len(verdict.get("findings", []))
    print(f"[fleet-sentinel] {ts} status={verdict['overall_status']} findings={n} -> {REPORT}")
    for f in verdict.get("findings", []):
        print(f"  [{f.get('severity')}] {f.get('host')}: {f.get('finding')}")

    if NTFY and verdict["overall_status"] != "healthy":
        try:
            req = urllib.request.Request(
                NTFY, data=verdict.get("summary", "")[:400].encode(),
                headers={"Title": f"Fleet {verdict['overall_status']} ({n} findings)",
                         "Priority": "high" if verdict["overall_status"] == "critical" else "default"})
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            print(f"[fleet-sentinel] ntfy push failed: {e}")


if __name__ == "__main__":
    main()
