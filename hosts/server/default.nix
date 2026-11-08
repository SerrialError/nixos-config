# Home server: old x86_64 laptop running Vaultwarden and Blocky behind
# Caddy. Deployed from the desktop (see README).
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # For the few server packages that stable no longer ships a usable version
  # of (currently only Immich). Inherits the system nixpkgs.config.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    inherit (config.nixpkgs) config;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../profiles/server.nix
    ./monitoring.nix
  ];

  networking.hostName = "server";

  # Unattended upgrades straight from GitHub main. CI bumps flake.lock
  # (.github/workflows/update-lock.yml) and only pushes it once all three
  # hosts build, so this tracks a tested lock. Reboots only when the kernel,
  # modules or initrd changed, and only inside the window; otherwise it
  # switches in place. Note this also reverts anything deployed with `srs`
  # that isn't pushed to main.
  system.autoUpgrade = {
    enable = true;
    flake = "github:SerrialError/nixos-config#server";
    # The eval reads the agenix-decrypted ssh-auth-keys (see modules/common.nix).
    flags = [ "--impure" ];
    # `--upgrade` refreshes nix-channels; the flake lock is the pin here.
    upgrade = false;
    dates = "04:00";
    randomizedDelaySec = "30min";
    allowReboot = true;
    rebootWindow = {
      lower = "03:30";
      upper = "05:30";
    };
  };

  # Old BIOS laptop -> GRUB on the disk MBR. Kept here (not in the
  # hardware-configuration.nix placeholder) so it survives replacing that
  # file with the generated one. Adjust the device if the install disk
  # isn't /dev/sda.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  ############################################################################
  # Caddy — TLS-terminating reverse proxy for Vaultwarden.
  #
  # jumpsquad.org sits behind Cloudflare (proxied / orange-cloud), so the home
  # IP never appears in public DNS. Certs are issued over the ACME DNS-01
  # challenge via the Cloudflare API instead of HTTP-01 — that means cert
  # issuance needs no inbound ports, only outbound API access.
  #
  # The NixOS ACME module (lego, which speaks Cloudflare DNS natively) issues
  # and renews the cert, and stock caddy just serves it. This replaced a caddy
  # built with the caddy-dns/cloudflare plugin, whose fixed-output hash broke
  # on nixpkgs bumps. With useACMEHost, the caddy module puts the cert in the
  # caddy group, orders caddy after acme-<host>.service and reloads it on
  # renewal.
  ############################################################################
  services.caddy = {
    enable = true;
    # Only Vaultwarden is served; no static site is hosted on this machine.
    virtualHosts."vault.jumpsquad.org" = {
      useACMEHost = "vault.jumpsquad.org";
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
      '';
    };
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "contact@jumpsquad.org";
    certs."vault.jumpsquad.org" = {
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets.cloudflare-api-token.path;
      # Check propagation against public DNS, not the local Blocky resolver.
      dnsResolver = "1.1.1.1:53";
    };
  };
  # Cloudflare API token (Zone:DNS:Edit + Zone:Read on jumpsquad.org), read by
  # lego as CLOUDFLARE_DNS_API_TOKEN for the DNS-01 challenge.
  age.secrets.cloudflare-api-token.file = ../../secrets/cloudflare-api-token.age;

  ############################################################################
  # Vaultwarden — localhost only; reached exclusively through Caddy.
  ############################################################################
  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://vault.jumpsquad.org";
      # No open registration, but anyone with a @jumpsquad.org address may
      # register: SIGNUPS_DOMAINS_WHITELIST permits those domains even while
      # SIGNUPS_ALLOWED is false.
      SIGNUPS_ALLOWED = false;
      SIGNUPS_DOMAINS_WHITELIST = "jumpsquad.org";
      # Only this account may create organizations (comma-separated list).
      ORG_CREATION_USERS = "contact@jumpsquad.org";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    };
    # Holds ADMIN_TOKEN=... — deployed by agenix (see age.secrets below).
    environmentFile = "/run/agenix/vaultwarden-env";
    # Daily sqlite `.backup` + attachment copy at 23:00 via the module's
    # built-in backup-vaultwarden.{service,timer}.
    # TODO: add an off-machine backup (e.g. restic/rclone of this directory
    # to another host or cloud storage) — a local copy alone won't survive
    # the laptop's disk dying.
    backupDir = "/var/backup/vaultwarden";
  };
  age.secrets.vaultwarden-env.file = ../../secrets/vaultwarden-env.age;
  # agenix re-decrypts the secret on activation, but nixos-rebuild only
  # restarts vaultwarden when its *unit* changes — so a secret-only rotation
  # (e.g. a new ADMIN_TOKEN) leaves the service running the stale value.
  # Tie a restart to the ciphertext hash so rotations actually take effect.
  systemd.services.vaultwarden.restartTriggers = [
    (builtins.hashFile "sha256" ../../secrets/vaultwarden-env.age)
  ];

  ############################################################################
  # Music library — received from the desktop over Syncthing, served by
  # Navidrome. The desktop's ~/Music (curated by beets) is the canonical
  # copy; this host only ever *receives* it (folder type "receiveonly"), so
  # a mistake here can never propagate back and clobber the library.
  #
  # Pre-create the folder root owned by the syncthing user before either
  # service starts: Navidrome's module would otherwise tmpfiles-create its
  # MusicFolder as navidrome:navidrome 0700 (unreadable to syncthing), and
  # syncthing would create its folder root 0700 (unreadable to navidrome).
  # 0755 + syncthing-owned lets Navidrome (a different user) read the tree;
  # Navidrome only needs read access. Synced music files carry their source
  # mode (0644 files / 0755 dirs), so they stay world-readable here.
  ############################################################################
  systemd.tmpfiles.rules = [
    "d /var/lib/music 0755 syncthing syncthing -"
    # Same arrangement for the audiobook folder (served by Audiobookshelf).
    "d /var/lib/audiobooks 0755 syncthing syncthing -"
  ];

  services.syncthing = {
    enable = true;
    # Manage devices/folders declaratively; drop anything added out-of-band.
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      # Admin GUI stays on localhost — reach it via `ssh -L 8384:localhost:8384`.
      gui.address = "127.0.0.1:8384";
      devices.desktop.id = "45MTBYT-4EMXCYJ-7I5AAT4-7PSLKSN-JEZ5BD2-YO4H4D7-BBU7JW5-H7MPPAF";
      folders.Music = {
        # Folder ID must match the desktop's ("Music"); path is local.
        path = "/var/lib/music";
        devices = [ "desktop" ];
        type = "receiveonly";
      };
      # Audiobooks are kept out of ~/Music (so Navidrome / mpd never mix
      # chapters into music) and arrive as their own folder.
      folders.Audiobooks = {
        path = "/var/lib/audiobooks";
        devices = [ "desktop" ];
        type = "receiveonly";
      };
    };
  };
  # Opens 22000/tcp+udp (sync) and 21027/udp (LAN discovery) in the firewall.
  services.syncthing.openDefaultPorts = true;

  ############################################################################
  # Navidrome — Subsonic-API music server, LAN-only.
  #
  # Bound to all interfaces + firewall-opened so phones/clients on the home
  # LAN can reach it directly; it is deliberately NOT put behind the public
  # Caddy vhost (unlike Vaultwarden) to avoid streaming media through
  # Cloudflare's proxy. For off-LAN access, add a VPN (e.g. Tailscale) later
  # and this can go back to 127.0.0.1.
  ############################################################################
  services.navidrome = {
    enable = true;
    openFirewall = true; # opens settings.Port (4533/tcp)
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/var/lib/music";
    };
  };

  ############################################################################
  # Audiobookshelf — audiobook server (resume position, chapters, sleep timer,
  # phone apps), LAN-only like Navidrome. Books are made on the desktop by
  # make-audiobook into ~/Audiobooks and arrive here over Syncthing.
  #
  # Libraries live in its database, not in Nix: on first visit
  # (http://audiobooks.home:13378) create the admin user, then add a "Books"
  # library with folder /var/lib/audiobooks. It only needs read access, which
  # the 0755 tree above gives it.
  ############################################################################
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    port = 13378;
    openFirewall = true;
  };

  ############################################################################
  # Immich — self-hosted photo/video library, LAN-only.
  #
  # Like Navidrome, this is bound to all interfaces + firewall-opened so
  # phones/clients on the home LAN reach it directly over HTTP; it is NOT put
  # behind Caddy (Caddy's only cert path here is Cloudflare DNS-01 for
  # jumpsquad.org, and this service is deliberately never public). Blocky maps
  # `immich.home` -> this box's LAN IP for a friendly in-house URL; the mobile
  # app is happy with plain `http://immich.home:2283` (or the raw IP).
  #
  # On stateVersion 25.11 the module defaults to the VectorChord Postgres
  # extension (database.enableVectorChord = true, enableVectors = false), which
  # is the modern path and avoids the pgvecto.rs / PostgreSQL-17 assertion. With
  # the default unix-socket DB no secrets file is required, so there's no agenix
  # secret to wire in. The module provisions Postgres + Redis itself.
  #
  # The package comes from nixpkgs-unstable: 26.05 ships only Immich 2.x, which
  # is EOL and marked insecure (CVE-2026-59258, CVE-2026-82272). The 26.05
  # module drives 3.x fine (same VectorChord). The 2 -> 3 DB migration is
  # one-way, so there is no rolling back to a 2.x package afterwards. Drop the
  # override once stable ships 3.x (NixOS 26.11).
  #
  # Machine learning (face recognition / smart search / OCR) is DISABLED: it is
  # the heaviest component and this is a 2GB Core 2 Duo already running
  # Vaultwarden + the monitoring stack. Can be enabled later once we've seen how
  # the core service behaves under load.
  ############################################################################
  services.immich = {
    enable = true;
    package = pkgs-unstable.immich;
    host = "0.0.0.0"; # LAN-reachable, like Navidrome
    port = 2283;
    openFirewall = true; # opens 2283/tcp
    mediaLocation = "/var/lib/immich"; # module's StateDirectory; on the OS disk
    machine-learning.enable = false;
  };

  # Memory backstop for the Immich process group. The module puts immich-server
  # in its own `system-immich.slice`; cap it so that under memory pressure on
  # this 2GB box Immich is the OOM victim, never Vaultwarden. MemoryHigh
  # throttles+reclaims (soft) first; MemoryMax is the hard ceiling. Tunable —
  # raise if Immich thrashes/restarts during large imports. # 2GB
  systemd.slices.system-immich.sliceConfig = {
    MemoryHigh = "700M";
    MemoryMax = "900M";
  };

  ############################################################################
  # Taskwarrior sync (TaskChampion) — LAN/WireGuard-only, like Navidrome/Immich.
  #
  # Plain HTTP; task data is end-to-end encrypted by the clients (the server
  # only ever stores ciphertext), so no TLS/Caddy vhost is needed and this is
  # deliberately NOT public. Reached by the desktop directly on the LAN and by
  # the phone over the router's WireGuard tunnel (WG clients route to this LAN).
  #
  # In TaskChampion the client_id identifies the shared *task list*, not the
  # device: every replica that shares tasks uses the SAME client_id and the same
  # encryption_secret ("configure a new replica identically to the existing
  # one"). So this is one id for all of connor's devices, not one per device.
  # It is not secret; the shared encryption_secret lives in agenix on the
  # desktop and is typed into the phone app, never here.
  ############################################################################
  services.taskchampion-sync-server = {
    enable = true;
    host = "0.0.0.0"; # LAN-reachable, like Navidrome/Immich
    port = 10222; # 8080 is taken by Gatus (see monitoring.nix)
    openFirewall = true; # opens 10222/tcp
    allowClientIds = [
      "5a1322be-3f3a-4354-a430-90b9325ddb41" # connor's task list (all devices)
    ];
  };
  # TEMP diagnostic: the server uses env_logger + actix's Logger middleware, so
  # RUST_LOG=info makes it log every HTTP request (method, path, status). Used
  # to see whether the phone's sync requests arrive and how the server answers.
  # Remove once phone sync is confirmed working.
  systemd.services.taskchampion-sync-server.environment.RUST_LOG = "info";

  ############################################################################
  # Blocky — DNS ad/tracker blocking for the LAN, listening on :53.
  ############################################################################
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53; # tcp + udp
      # Quad9 over DoT, plain Quad9 as fallback.
      upstreams.groups.default = [
        "tcp-tls:dns.quad9.net"
        "9.9.9.9"
      ];
      # Needed to resolve the DoT upstream's hostname at startup.
      bootstrapDns = "tcp+udp:9.9.9.9";
      # Split-horizon records: resolve the Immich / Audiobookshelf hostnames to this box's LAN IP
      # for in-house devices. The .245 address is DHCP-assigned today — keep a
      # router DHCP reservation for it so this mapping stays correct.
      customDNS.mapping = {
        "immich.home" = "192.168.1.245";
        "audiobooks.home" = "192.168.1.245";
      };
      blocking = {
        denylists.ads = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };
    };
  };

  # The blocky module Wants network-online.target but doesn't order After it,
  # so at boot the blocklist download races the network and silently fails,
  # leaving DNS unfiltered until the next refresh (hours later).
  systemd.services.blocky.after = [ "network-online.target" ];

  # 80/443 for Caddy, 53 for Blocky. SSH (22) is opened by the openssh
  # module itself. Nothing else.
  networking.firewall.allowedTCPPorts = [
    53
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  # Set at first install; do not change afterwards.
  system.stateVersion = "25.11";
}
