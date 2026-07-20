# Home server: old x86_64 laptop running Vaultwarden and Blocky behind
# Caddy. Deployed from the desktop (see README).
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../profiles/server.nix
    ./monitoring.nix
  ];

  networking.hostName = "server";

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
  # issuance needs no inbound ports, only outbound API access. The stock caddy
  # binary can't do DNS-01, so we build it with the caddy-dns/cloudflare plugin.
  ############################################################################
  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-Q0lgI8MY90u/5R/xXBVPQWCZBN7dUZ0kcuDxD0xd0fo=";
    };
    # All sites use DNS-01 via Cloudflare. The token comes from the agenix
    # secret wired into caddy's EnvironmentFile below.
    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    '';
    # Only Vaultwarden is served; no static site is hosted on this machine.
    virtualHosts."vault.jumpsquad.org".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
    '';
  };
  # Cloudflare API token (Zone:DNS:Edit + Zone:Read on jumpsquad.org), read by
  # caddy as CLOUDFLARE_API_TOKEN for the DNS-01 challenge.
  age.secrets.cloudflare-api-token.file = ../../secrets/cloudflare-api-token.age;
  systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.cloudflare-api-token.path;

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
