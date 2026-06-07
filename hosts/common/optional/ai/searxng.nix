# SearXNG — self-hosted metasearch for the AI lab (web search for agents/Open WebUI).
# wg0-only, served via uwsgi. Secret key generated off-git (never in the repo).

{ pkgs, ... }:

{
  services.searx = {
    enable = true;
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
      # Google blocks self-hosted scrapers (403 spam); disable it. Others suffice.
      engines = [ { name = "google"; disabled = true; } ];
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
