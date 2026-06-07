"""Host Health MCP Server — local system health tools for Claude Code."""

import asyncio
import json
import subprocess
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("host-health")


def run(cmd: list[str], timeout: int = 10) -> str:
    """Run a command and return stdout, or an error string."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() or r.stderr.strip()
    except subprocess.TimeoutExpired:
        return f"ERROR: command timed out after {timeout}s"
    except FileNotFoundError:
        return f"ERROR: {cmd[0]} not found"


@mcp.tool()
def pool_status() -> str:
    """Get ZFS pool health, capacity, and last scrub status for all pools."""
    lines = []

    pool_list = run(["zpool", "list", "-H", "-o", "name,size,alloc,free,cap,health"])
    if pool_list.startswith("ERROR"):
        return pool_list
    lines.append("POOL        SIZE   ALLOC   FREE    CAP  HEALTH")
    lines.append(pool_list)
    lines.append("")

    pools = [line.split()[0] for line in pool_list.splitlines() if line.strip()]
    for pool in pools:
        status = run(["zpool", "status", pool])
        for sline in status.splitlines():
            stripped = sline.strip()
            if stripped.startswith("scan:") or stripped.startswith("scrub"):
                lines.append(f"{pool} scrub: {stripped}")
                break
        for sline in status.splitlines():
            stripped = sline.strip()
            if stripped.startswith("errors:"):
                lines.append(f"{pool} errors: {stripped}")
                break

    return "\n".join(lines)


@mcp.tool()
def service_status(services: list[str] | None = None) -> str:
    """Check systemd service status. Defaults to key infrastructure services.

    Args:
        services: Optional list of service names to check. Defaults to
                  wireguard, sshd, syncthing, fail2ban, zfs targets.
    """
    if services is None:
        services = [
            "wireguard-wg0.service",
            "sshd.service",
            "syncthing.service",
            "fail2ban.service",
            "zfs-scrub-weekly.timer",
            "zfs-auto-snapshot-hourly.timer",
        ]

    lines = []
    for svc in services:
        raw = run(["systemctl", "is-active", svc])
        state = raw.splitlines()[0] if raw else "unknown"
        lines.append(f"{svc}: {state}")

    failed = run(["systemctl", "--failed", "--no-legend", "--no-pager"])
    if failed:
        lines.append("")
        lines.append("FAILED UNITS:")
        lines.append(failed)
    else:
        lines.append("")
        lines.append("No failed units.")

    return "\n".join(lines)


@mcp.tool()
def journal_errors(since: str = "24h ago", priority: str = "err", limit: int = 50) -> str:
    """Get recent journal errors/warnings.

    Args:
        since: Time window (e.g. "1h ago", "24h ago", "today"). Default: 24h ago.
        priority: Minimum priority level (emerg, alert, crit, err, warning). Default: err.
        limit: Maximum number of lines to return. Default: 50.
    """
    raw = run(
        [
            "journalctl",
            f"--since={since}",
            f"--priority={priority}",
            "--no-pager",
            f"--lines={limit}",
            "--output=short-precise",
        ],
        timeout=15,
    )
    if not raw or "No entries" in raw or raw.startswith("ERROR"):
        return raw or "No journal entries matching criteria."
    return raw


@mcp.tool()
def ollama_models() -> str:
    """List models available in Ollama with their sizes."""
    raw = run(["ollama", "list"], timeout=15)
    if raw.startswith("ERROR"):
        return raw
    return raw or "No models installed."


@mcp.tool()
def disk_usage() -> str:
    """Get disk usage for all ZFS datasets and key mount points."""
    zfs = run(["zfs", "list", "-o", "name,used,avail,refer,mountpoint"])
    return zfs


if __name__ == "__main__":
    mcp.run(transport="stdio")
