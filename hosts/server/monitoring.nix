# Observability stack for the home server (2GB RAM HP EliteBook 8530W).
#
# Deliberately lightweight — the VictoriaMetrics ecosystem was chosen over
# Prometheus/Grafana/Loki because a single Go binary each keeps RSS tiny on a
# box that also runs Vaultwarden (which must never be the OOM victim):
#
#   VictoriaMetrics  metrics TSDB + scraper + bundled vmui  (127.0.0.1:8428)
#   node_exporter    host metrics incl. hwmon/thermal       (127.0.0.1:9100)
#   VictoriaLogs     log DB + bundled UI                    (127.0.0.1:9428)
#   journal-upload   ships journald -> VictoriaLogs         (systemd builtin)
#   Gatus            uptime/temperature probes + ALL alerts (127.0.0.1:8080)
#
# SECURITY: vmui (:8428), VictoriaLogs (:9428) and Gatus (:8080) are bound to
# 0.0.0.0 and firewall-opened so any machine on the LAN can browse them. They
# have NO authentication — anyone on the LAN can read all metrics and every log
# line (including Vaultwarden/system logs). This is an accepted trade-off for a
# trusted home LAN; to lock it down again, set the listenAddress/web.address
# back to 127.0.0.1, drop the firewall ports below, and use an SSH tunnel:
#   ssh -L 8428:localhost:8428 -L 9428:localhost:9428 -L 8080:localhost:8080 server
# node_exporter stays localhost-only (it's only a scrape target, no UI).
#
# MEMORY CAPS: values suffixed "# 2GB" were picked for this machine. On better
# hardware they can be relaxed. The application-level -memory.allowed* flags cap
# only each binary's *caches*; the systemd MemoryMax/High lines are the real
# backstop on total RSS.
{ config, pkgs, ... }:

{
  ############################################################################
  # VictoriaMetrics — single-node: TSDB + scraper + vmui, no vmagent/vmalert.
  ############################################################################
  services.victoriametrics = {
    enable = true;
    listenAddress = "0.0.0.0:8428"; # LAN-exposed, auth-less — see header note
    retentionPeriod = "90d";
    # Cap cache memory in absolute bytes rather than -memory.allowedPercent:
    # percent is of *total* RAM (2GB), which would let caches alone reach
    # ~300MB. Absolute keeps it predictable. # 2GB
    extraOptions = [ "-memory.allowedBytes=64MB" ];
    prometheusConfig = {
      # 30s not 15s: two slow Core 2 Duo cores — halve the scrape load. # 2GB
      global.scrape_interval = "30s";
      scrape_configs = [
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
      ];
    };
  };
  systemd.services.victoriametrics.serviceConfig = {
    MemoryHigh = "180M"; # 2GB
    MemoryMax = "220M"; # 2GB
  };

  ############################################################################
  # node_exporter — host metrics. hwmon is the one that matters (CPU temp).
  #
  # After first boot run `sudo sensors-detect --auto` once and confirm
  # `sensors` shows coretemp before trusting node_hwmon_temp_celsius. coretemp
  # is force-loaded below so temps are usually present without that step.
  ############################################################################
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [
      "systemd"
      "hwmon"
      "thermal_zone"
    ];
  };
  systemd.services.prometheus-node-exporter.serviceConfig.MemoryMax = "64M"; # 2GB
  boot.kernelModules = [ "coretemp" ];
  environment.systemPackages = [ pkgs.lm_sensors ];

  ############################################################################
  # VictoriaLogs — log database + bundled UI at :9428/select/vmui.
  # No retentionPeriod NixOS option here (unlike victoriametrics) — via flags.
  ############################################################################
  services.victorialogs = {
    enable = true;
    listenAddress = "0.0.0.0:9428"; # LAN-exposed, auth-less — see header note
    extraOptions = [
      "-retentionPeriod=30d"
      "-memory.allowedBytes=64MB" # 2GB
    ];
  };
  systemd.services.victorialogs.serviceConfig = {
    MemoryHigh = "180M"; # 2GB
    MemoryMax = "220M"; # 2GB
  };

  ############################################################################
  # journald -> VictoriaLogs shipping.
  #
  # systemd-journal-upload streams the journal to VL over one long-lived
  # chunked request and persists a cursor (--save-state), so it resumes across
  # reboots. VictoriaLogs 1.38 has no -journald.maxRequestSize limit (the
  # endpoint is streaming), so the old "first-run large journal -> HTTP 400"
  # pitfall does not apply here. We still bound the local journal below so it's
  # a buffer, not the retention layer — VL keeps 30d.
  ############################################################################
  services.journald.upload = {
    enable = true;
    settings.Upload.URL = "http://127.0.0.1:9428/insert/journald";
  };
  # Don't hammer VL before it's up (the unit already Restart=always retries).
  systemd.services.systemd-journal-upload = {
    after = [ "victorialogs.service" ];
    wants = [ "victorialogs.service" ];
  };
  services.journald.extraConfig = "SystemMaxUse=500M"; # 2GB — VL is retention

  ############################################################################
  # Gatus — outage + temperature probes and ALL alerting (replaces vmalert +
  # Alertmanager). ntfy creds come from the agenix gatus-env file, interpolated
  # into the config as ${NTFY_*} at load time.
  ############################################################################
  age.secrets.gatus-env.file = ../../secrets/gatus-env.age;
  services.gatus = {
    enable = true;
    environmentFile = config.age.secrets.gatus-env.path;
    settings = {
      web = {
        address = "0.0.0.0"; # LAN-exposed, auth-less — see header note
        port = 8080;
      };
      alerting.ntfy = {
        url = "\${NTFY_URL}";
        topic = "\${NTFY_TOPIC}";
        token = "\${NTFY_TOKEN}";
        priority = 4;
        default-alert = {
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };
      endpoints = [
        {
          name = "caddy";
          group = "services";
          # Caddy's local admin API — proves the process is up and serving.
          url = "http://127.0.0.1:2019/config/";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "vaultwarden";
          group = "services";
          url = "http://127.0.0.1:8222/alive";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "blocky-dns";
          group = "services";
          url = "127.0.0.1"; # DNS resolver address (port 53)
          dns = {
            query-name = "example.com";
            query-type = "A";
          };
          interval = "60s";
          conditions = [ "[DNS_RCODE] == NOERROR" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "navidrome";
          group = "services";
          url = "http://127.0.0.1:4533/app/";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "syncthing";
          group = "services";
          url = "http://127.0.0.1:8384/rest/noauth/health";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "immich";
          group = "services";
          url = "http://127.0.0.1:2283/api/server/ping";
          interval = "60s";
          conditions = [ "[STATUS] == 200" ];
          alerts = [ { type = "ntfy"; } ];
        }
        {
          name = "cpu-temperature";
          group = "health";
          # Assert the CPU package (coretemp) stays under 85C — the thermal
          # alert, no vmalert needed. We filter to chip="platform_coretemp_0"
          # on purpose: max() over *all* hwmon sensors would pick the unused
          # discrete GPU (idles ~82C; EC-controlled fan, no driver to cool it)
          # and flap around the threshold for no actionable reason. The
          # braces/quotes in the PromQL are URL-encoded so Go's HTTP client
          # accepts the query string.
          url = "http://127.0.0.1:8428/api/v1/query?query=max(node_hwmon_temp_celsius%7Bchip%3D%22platform_coretemp_0%22%7D)";
          interval = "5m";
          conditions = [
            "[STATUS] == 200"
            "[BODY].data.result[0].value[1] < 85"
          ];
          alerts = [ { type = "ntfy"; } ];
        }
      ];
    };
  };
  systemd.services.gatus.serviceConfig = {
    MemoryHigh = "80M"; # 2GB
    MemoryMax = "100M"; # 2GB
  };

  ############################################################################
  # External dead-man's switch — the box can't report its own death, so a
  # timer pings healthchecks.io every 5min; healthchecks alerts if pings stop.
  # The ping URL is a capability, so it lives in agenix (root-only).
  ############################################################################
  age.secrets.healthchecks-url.file = ../../secrets/healthchecks-url.age;
  systemd.services.healthchecks-ping = {
    description = "Ping healthchecks.io dead-man's switch";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "healthchecks-ping" ''
        ${pkgs.curl}/bin/curl -fsS -m 10 --retry 3 "$(cat ${config.age.secrets.healthchecks-url.path})"
      '';
    };
  };
  systemd.timers.healthchecks-ping = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  ############################################################################
  # Memory & thermal safety rails — all mandatory on a hot 2GB laptop.
  ############################################################################
  zramSwap.enable = true; # compressed swap in RAM; ~50% by default. # 2GB
  powerManagement.cpuFreqGovernor = "powersave"; # run cool, not fast. # 2GB
  powerManagement.powertop.enable = true;
  # Headless: the discrete Quadro FX 770M is unused and just makes heat.
  boot.blacklistedKernelModules = [ "nouveau" ];

  # LAN access to the (auth-less) web UIs — see the header SECURITY note.
  # Merges with the 53/80/443 already opened in default.nix.
  networking.firewall.allowedTCPPorts = [
    8080 # Gatus
    8428 # VictoriaMetrics / vmui
    9428 # VictoriaLogs UI
  ];
}
