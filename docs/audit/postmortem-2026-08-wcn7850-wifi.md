# Postmortem — WCN7850 WiFi outage (2026-08-02 → 08-03)

**Status:** Resolved · **Severity:** High (workstation is WiFi-only; lost sole connectivity)
**Root cause class:** Automation-safety (a monitor perturbed the system it observed)

## TL;DR
A daily monitoring canary (`stack-smoke-test`) declared `wants = network-online.target`
with a `Persistent = true` timer. That pulled `network-online.target` into early boot,
brought NetworkManager up before the WCN7850's WiFi firmware finished initializing
(~13-29 s), NM grabbed the interface mid-init, and the card wedged
(`wpa_supplicant couldn't grab this interface`). **A passive health check silently
acquired the power to break the thing it sat next to.** Root cause was boot *ordering*,
not the kernel — but it was misdiagnosed as a kernel regression for most of the incident.

## Impact
- Intermittent WiFi loss across generations; WiFi-only host → each failed boot meant no
  connectivity and a blind reboot to a known-good generation.
- Multi-day debugging, ~15+ reboots; **two attempted fixes caused fresh outages**
  (a `qrtr` softdep experiment, then an `unmanaged`+handover hardening service).
- A wrong root cause was committed to config + audit doc before being corrected.

## Root cause & mechanism
The `ath12k_wifi7_pci` netdev (`wlp16s0`) appears ~13-29 s **before** the firmware is
grab-ready. Whether NetworkManager wins or loses that race is decided purely by **boot
ordering**. The monitoring's `network-online.target` want + `Persistent` catch-up run was
enough to flip ordering into the losing case (NM engages the interface at T+1 s). Without
it, NM starts ~13 s later and connects cleanly. Confirmed by generation bisection: gen 50
(no monitoring) works, gen 51 (+monitoring) fails — byte-identical kernel/initrd/driver/
firmware/NetworkManager otherwise (`nix store diff-closures` + recursive `/etc` diff).

## Why it took so long (contributing factors)
1. **Two variables changed together** — a nixpkgs/kernel bump *and* the monitoring. The
   investigation anchored on "kernel 7.0.14 regression" and stopped isolating.
2. **Small sample trusted over reproducible user observation** — called "intermittent
   hardware" when the user consistently saw a gen-boundary; their signal was correct.
3. **The definitive tool was used late** — generational byte-diffing cracked it in minutes
   but only after days of theorizing.
4. **Bad heuristic: "runs after the failure, so it can't be the cause"** — a unit's
   *presence in the dependency graph* matters, not just when its code runs.
5. **Fixes attempted before root cause proven**, on the only connectivity path, no fallback.

## Learnings

### Automation & monitoring design (primary)
- **Observability must be passive and isolated** — a monitor must be incapable of affecting
  the boot or health of what it observes. No `wants`/`requires` on `*.target` that pull the
  monitor into boot; use `After=` (ordering only), not `Wants=` (pull-in). Avoid
  `Persistent=true` on non-critical timers (forces a catch-up run into early boot). Gate
  canaries after `multi-user.target`/on a delay, never in the critical path.
- **A monitor that can't deliver its signal is pure liability** — these alerted to (and the
  smoke test *targeted*) the offline server, so value was zero while cost was this outage.
  Monitors should fail open and self-check their own alert path.
- **Mind blast radius** — behavior-changing modules should land on one host, be validated,
  then broadened; not fleet-wide by default.

### System management & resilience
- **Never leave the only path back with no fallback** — WiFi-only + a WiFi bug made every
  test high-stakes and blocked live repair. A cheap USB ethernet/WiFi dongle for
  out-of-band recovery is the single highest-leverage fix.
- **Treat bleeding-edge hardware (ath12k/WiFi 7) as a fragility zone** — isolate it; never
  couple critical connectivity to timing-sensitive init.

### Debugging & incident response
- **Isolate one variable at a time**; don't conclude root cause with another change in flight.
- **Bisect early on NixOS** — `nix store diff-closures` + recursive `/etc` diff between a
  working and failing generation is byte-exact; make it a first move.
- **Weight reproducible user observation above limited self-runs.**
- **When a mechanism seems impossible, the model is incomplete — keep digging.**
- **Elimination beats theory when static analysis stalls.**

### Change management & rollout safety
- **Fix root cause before adding mitigations** (the hardening service caused a new failure).
- **Each expensive test validates exactly one hypothesis**; pre-validate offline
  (build/eval/closure-diff).
- **Prefer `nixos-rebuild boot` + known-good default + boot-once** for risky changes.
- **Mid-incident conclusions can be wrong** — revisit after resolution (the "kernel
  regression" note was corrected once 7.0.14 booted cleanly with monitoring removed).

## Action items
| # | Action | Priority | Status |
|---|--------|----------|--------|
| 1 | Out-of-band recovery for the workstation (was: USB dongle) | High | **Planned** — switch + ethernet being purchased; server returns to wired then |
| 2 | Audit all sentinels/timers for boot-path coupling (no `Wants=*.target`, reconsider `Persistent`, gate after boot) | High | **Done** — `fleet-sentinel` + `update-advisor` decoupled (`769f86b`); `stack-smoke-test` removed |
| 3 | Monitors fail-open + self-check alert delivery; don't target/alert-to hosts that may be down | Medium | Open |
| 4 | Standard risky-change ritual: closure-diff pre-flight → `boot` not `switch` → known-good default → boot-once | Medium | Open (practiced this incident) |
| 5 | New modules land single-host first, then fleet-wide | Medium | Open |
| 6 | Re-add monitoring only decoupled from boot, once #2 done | Low | Open |
| 7 | **Server GPU-vs-ZFS kernel decision** — the ZFS-compatible pin (`latestCompatibleLinuxPackages`, commit `a9fd5cb`) drops the server to **6.12 LTS**; the gfx1151/Strix Halo APU may need a newer kernel for full amdgpu/ROCm. **When the server returns to wired: deploy, then verify ollama-rocm + ComfyUI on 6.12.** If the GPU stack regresses, switch to Option B — keep a recent kernel + `boot.zfs.package = pkgs.zfs_unstable`. | High | **Blocked on server return** |

## Resolution
- Dropped `stack-smoke-test` + `post-rebuild-verify` from the workstation (commit `183f279`).
- Confirmed kernel 7.0.14 / nixpkgs 2026-06-30 boots WiFi cleanly with monitoring removed;
  lifted the 7.0.10 hold, advanced `flake.lock` (commit `0bc7e1b`).
- Corrected the earlier "kernel regression" notes.

**One-line takeaway:** this was not a hardware or kernel failure — it was an
automation-safety failure. A monitor gained the ability to break its host because
"observability must not perturb the observed" was not a hard design rule.
