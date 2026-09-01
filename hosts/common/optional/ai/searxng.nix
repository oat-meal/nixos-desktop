# SearXNG — self-hosted metasearch for the AI lab (web search for agents/Open WebUI).
# wg0-only, served via uwsgi. Secret key generated off-git (never in the repo).
#
# ⚠️ THIS IS AN API-BACKED INSTANCE, NOT A WEB-SCRAPING ONE, and that is the
# whole design after 2026-08-31. Every commercial engine that works by scraping
# refuses this host: measured, four of them say so outright (duckduckgo CAPTCHA,
# brave "too many requests", mojeek and qwant "access denied"), and Bing does
# NOT — it silently serves ten unrelated results instead. Full diagnosis,
# including eleven refuted hypotheses, in docs/searxng-engines-degraded.md.
#
# The reputation is attached to the traffic PATTERN, not to any request
# attribute: curl and httpx from this same host, with any user-agent and any
# parameters, get correct results every time. So there is nothing to tune. The
# engines that work are the ones that expect robots — documented APIs.

{ pkgs, ... }:

{
  services.searx = {
    enable = true;
    # One release ahead of nixos-26.05 (2026-07-26 vs 2026-05-16), following the
    # lab's existing pkgs.unstable.* pattern.
    #
    # ⚠️ THIS IS HYGIENE, NOT THE FIX, and it is labelled so because it looked
    # like the fix. bing.py's result-extraction XPath is BYTE-IDENTICAL between
    # the two versions — only `number_of_results` scraping and redirect handling
    # changed. Upgrading on the theory that a stale parser was the cause would
    # have changed nothing and been reported as a repair.
    package = pkgs.unstable.searxng;
    # Secret injected via envsubst from this file (generated below, not in git).
    environmentFile = "/var/lib/searx-secret/secret.env";
    configureUwsgi = true;
    uwsgiConfig = {
      http = "10.100.0.2:8888"; # wg0
      disable-logging = true;
    };
    settings = {
      server.secret_key = "$SEARX_SECRET_KEY"; # substituted from environmentFile
      server.bind_address = "10.100.0.2";
      server.port = 8888;
      general.instance_name = "lab-search";
      # JSON enabled for programmatic use by the research tool.
      search.formats = [ "html" "json" ];

      # ENGINES. Measured 2026-08-31 with the probe term `Nothofagus` — generic
      # enough to be indexed everywhere, distinctive enough that irrelevance is
      # unmistakable. Counts are results / results actually mentioning the term.
      engines = [
        # ── DISABLED: scrapers this host is blocked from ───────────────────
        #
        # ⚠️ bing is the ONLY ONE THAT HAD TO BE TURNED OFF RATHER THAN LEFT TO
        # FAIL, and it is the reason this list exists. It returns HTTP 200 with
        # exactly ten results and an EMPTY `unresponsive_engines`, so nothing at
        # any layer reports a problem — but 4 of 7 probe queries came back with
        # zero results mentioning their own distinctive term. `Brachystegia`
        # returned Social Security pages on one run and DC Lottery on the next;
        # `Nothofagus` returned city-data forums, youtube.com/?gl=ES and a
        # Mexican benefits site in one result set. Generic high-traffic filler,
        # served fresh each time.
        #
        # A blocked engine costs an answer. This one costs a WRONG answer that
        # nothing flags, which is strictly worse — leaving it enabled would keep
        # feeding fabricated-but-plausible sources to every consumer.
        { name = "bing"; disabled = true; }
        # Google blocks self-hosted scrapers (403 spam). Predates this pass.
        { name = "google"; disabled = true; }
        # These three fail HONESTLY — they report themselves unresponsive and
        # SearXNG passes that through, so they cost latency rather than trust.
        # Disabled anyway: 100% failure is not worth the round-trip on every
        # query, and re-enabling is a one-line change if reputation recovers.
        { name = "duckduckgo"; disabled = true; }   # CAPTCHA
        { name = "brave"; disabled = true; }        # Suspended: too many requests
        { name = "qwant"; disabled = true; }        # Suspended: access denied
        { name = "mojeek"; disabled = true; }       # Suspended: access denied

        # ── ENABLED: APIs, which cannot be blocked for looking like a robot ──
        # They expect robots. That is the entire reason these still work while
        # every scraper above does not.
        { name = "crossref"; disabled = false; }      # 20 results / 25 mentions
        { name = "openalex"; disabled = false; }      # 10 / 11
        { name = "wikipedia"; disabled = false; }     #  2 /  1 — narrow, correct
        { name = "wikispecies"; disabled = false; }   #  5 / 10
        { name = "wikidata"; disabled = false; }      #  0 — no match, reported cleanly
        { name = "arxiv"; disabled = false; }         #  0 — no match, reported cleanly
        { name = "pubmed"; disabled = false; }        # 20 /  0 — honest: a medical
                                                      # corpus has no Nothofagus
      ];

      # ⚠️ WHAT THIS INSTANCE IS NOW GOOD AT HAS CHANGED, and pretending
      # otherwise is how a consumer gets surprised. It answers technical,
      # scientific and reference questions well and GENERAL WEB QUESTIONS NOT AT
      # ALL. If general web search is needed, the root-cause fix is an API key
      # (Brave Search API, Azure, Tavily, Exa) — SearXNG supports key-based
      # engines, and buying one stops this host being a scraper. Anything else
      # is cat-and-mouse with a party that has already decided the answer.
    };
  };

  # Generate the SearXNG secret key out of band (persisted, never committed).
  systemd.services.searx-secret-key = {
    description = "Generate SearXNG secret key (off-git)";
    wantedBy = [ "multi-user.target" ];
    before = [ "searx-init.service" "uwsgi.service" "searx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0750 /var/lib/searx-secret
      f=/var/lib/searx-secret/secret.env
      if [ ! -s "$f" ]; then
        printf 'SEARX_SECRET_KEY=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > "$f"
        chmod 0600 "$f"
      fi
    '';
  };
}
