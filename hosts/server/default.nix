# Home server: old x86_64 laptop running the website, Vaultwarden and
# Blocky behind Caddy. Deployed from the desktop (see README).
{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix # PLACEHOLDER until generated on the laptop
    ../../modules/common.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "server";

  # Old BIOS laptop -> GRUB on the disk MBR. Kept here (not in the
  # hardware-configuration.nix placeholder) so it survives replacing that
  # file with the generated one. Adjust the device if the install disk
  # isn't /dev/sda.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  ############################################################################
  # Caddy — TLS-terminating reverse proxy / static site host.
  # Search-and-replace PLACEHOLDER-DOMAIN with the real domain.
  ############################################################################
  services.caddy = {
    enable = true;
    # Static website; drop the site files into /var/www/site.
    virtualHosts."PLACEHOLDER-DOMAIN".extraConfig = ''
      root * /var/www/site
      file_server
    '';
    virtualHosts."vault.PLACEHOLDER-DOMAIN".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
    '';
  };

  ############################################################################
  # Vaultwarden — localhost only; reached exclusively through Caddy.
  ############################################################################
  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://vault.PLACEHOLDER-DOMAIN";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    };
    # Holds ADMIN_TOKEN=... — deployed by agenix, see the TODO below.
    environmentFile = "/run/agenix/vaultwarden-env";
    # Daily sqlite `.backup` + attachment copy at 23:00 via the module's
    # built-in backup-vaultwarden.{service,timer}.
    # TODO: add an off-machine backup (e.g. restic/rclone of this directory
    # to another host or cloud storage) — a local copy alone won't survive
    # the laptop's disk dying.
    backupDir = "/var/backup/vaultwarden";
  };
  # TODO(bootstrap): uncomment after the server's host key is added to
  # secrets/secrets.nix and secrets/vaultwarden-env.age has been created
  # (`cd secrets && agenix -e vaultwarden-env.age`). Until the secret is
  # deployed, vaultwarden.service will fail to start — expected.
  # age.secrets.vaultwarden-env.file = ../../secrets/vaultwarden-env.age;

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
