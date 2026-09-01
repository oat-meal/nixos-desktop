#!/usr/bin/env python3
"""Does the lab's search actually SEARCH? Asserts relevance, not liveness.

WHY THIS EXISTS. On 2026-08-31 SearXNG was healthy by every check the lab made
— up, HTTP 200, answering in 0.8 s, JSON API exactly as configured — and it was
returning Social Security pages for `Brachystegia`. A liveness probe on port
8888 passed throughout and would pass today against a completely useless
service. See docs/searxng-engines-degraded.md.

THE CHECK IS RELEVANCE. For each probe, ask for a term distinctive enough that
its absence from every result is unambiguous, then require that the term appear
in at least MIN_HITS of the returned titles/URLs. A search engine that cannot
put the query's own rare word into one result out of ten is not searching,
whatever its status code says.

⚠️ THIS DELIBERATELY DOES NOT TEST `number_of_results`. That field reads 0 both
when nothing matched and when nothing ANSWERED — opposite facts, same value —
which is the ambiguity that let the outage hide. Relevance separates them.

Prints a count beside every verdict, per the lab rule: a green result is only
evidence if you know what it examined.

Exit 0 = every probe relevant. Exit 1 = at least one engine is lying or dead.
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = os.environ.get("SEARCH_URL", "http://10.100.0.2:8888/search")
TIMEOUT = int(os.environ.get("SEARCH_TIMEOUT", "45"))
MIN_HITS = int(os.environ.get("SEARCH_MIN_HITS", "1"))
NTFY_URL = os.environ.get("NTFY_URL", "")

#: How many engines must come back relevant for the instance to count as
#: working. NOT all of them, deliberately.
#:
#: ⚠️ THE FIRST VERSION REQUIRED EVERY ENGINE AND WOULD HAVE FLAPPED ON NIGHT
#: ONE. `wikipedia` returned 2 results on one run and 0 on the next, minutes
#: apart, for the same query — its engine only matches near-exact article
#: titles and it rate-limits. A monitor that cries wolf gets muted, and a muted
#: monitor is worse than no monitor because it looks like coverage.
#:
#: The two outcomes are NOT equally bad and the criterion says so:
#:   - an engine returning NOTHING is tolerable if its peers answer (it costs
#:     an answer, and it is self-reporting)
#:   - an engine returning RESULTS THAT ARE NOT ABOUT THE QUERY is never
#:     tolerable at any quorum, because that is the failure nothing else
#:     catches. One is enough to fail the run.
MIN_RELEVANT_ENGINES = int(os.environ.get("SEARCH_MIN_ENGINES", "2"))

#: (engine, query, term that must appear). Terms are rare binomials on purpose:
#: a common word would be matched by filler and the probe would pass vacuously.
#: Engines listed here must be the ones searxng.nix ENABLES — a probe against a
#: disabled engine tests nothing and reports a confident zero.
PROBES = [
    ("crossref", "Nothofagus forest ecology", "nothofagus"),
    ("openalex", "Nothofagus forest ecology", "nothofagus"),
    ("wikispecies", "Nothofagus", "nothofagus"),
    ("wikipedia", "Nothofagus", "nothofagus"),
]


def query(engine, q):
    url = BASE + "?" + urllib.parse.urlencode(
        {"q": q, "format": "json", "engines": engine})
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
        return json.load(r)


def main():
    probes = PROBES
    only = os.environ.get("SEARCH_ENGINES", "")
    if only:                  # for negative-control runs; see the module test
        want = {e.strip() for e in only.split(",")}
        probes = [p for p in PROBES if p[0] in want] or [
            (e, "Nothofagus forest ecology", "nothofagus") for e in sorted(want)]

    rows, relevant, lying, silent = [], [], [], []
    for engine, q, term in probes:
        try:
            d = query(engine, q)
        except (urllib.error.URLError, OSError, ValueError) as e:
            rows.append((engine, -1, -1, f"UNREACHABLE {type(e).__name__}"))
            silent.append(engine)
            continue

        results = d.get("results", [])
        dead = [x[0] for x in d.get("unresponsive_engines", [])]
        hits = sum(1 for x in results
                   if term in (str(x.get("title", "")) + " "
                               + str(x.get("url", ""))).lower())

        if hits >= MIN_HITS:
            verdict = "ok"
            relevant.append(engine)
        elif not results:
            verdict = ("no results — nothing answered"
                       + (f" (unresponsive: {','.join(dead)})" if dead else ""))
            silent.append(engine)
        else:
            # ⚠️ THE FAILURE THIS WHOLE SENTINEL EXISTS FOR. Results present,
            # none about the query, no error anywhere in the response.
            verdict = f"IRRELEVANT — {len(results)} results, 0 mention {term!r}"
            lying.append(engine)
        rows.append((engine, len(results), hits, verdict))

    w = max(len(r[0]) for r in rows)
    print(f"  {'engine':{w}s} {'n':>4s} {'hits':>5s}  verdict")
    for engine, n, hits, verdict in rows:
        ns = "--" if n < 0 else str(n)
        hs = "--" if hits < 0 else str(hits)
        print(f"  {engine:{w}s} {ns:>4s} {hs:>5s}  {verdict}")

    print(f"\n  {len(relevant)}/{len(rows)} engine(s) relevant "
          f"(need >={MIN_RELEVANT_ENGINES}); {len(silent)} silent, "
          f"{len(lying)} returning irrelevant results.")

    problems = []
    if lying:
        problems.append(f"{len(lying)} engine(s) returning IRRELEVANT results "
                        f"with no error: {', '.join(lying)}")
    if len(relevant) < MIN_RELEVANT_ENGINES:
        problems.append(f"only {len(relevant)} of {len(rows)} engine(s) "
                        f"relevant, need {MIN_RELEVANT_ENGINES}")

    if problems:
        msg = "lab-search degraded: " + "; ".join(problems)
        print(f"  FAIL: {msg}")
        if NTFY_URL:
            try:
                urllib.request.urlopen(urllib.request.Request(
                    NTFY_URL, data=msg.encode(),
                    headers={"Title": "SearXNG relevance", "Priority": "default"}),
                    timeout=10)
            except OSError:
                pass          # a monitor that dies on its own alerting is worse
        return 1

    print("  OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
