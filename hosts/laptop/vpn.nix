# NetworkManager VPN profiles for the laptop.
#
# WireGuard tunnels are defined declaratively as NM connection profiles (rather
# than networking.wg-quick) so they show up in nm-applet and toggle from the
# tray with no sudo — and so NM owns both wifi and tunnel, which removes the
# resolv.conf race two independent resolvconf writers would otherwise create.
# Future tunnels (e.g. ProtonVPN, which ships native WireGuard configs) drop in
# as additional entries under ensureProfiles.profiles.
#
# Secret handling: the private key never enters the store. It lives in agenix
# (wg-laptop-private.age) formatted as `WG_PRIVKEY=<key>`, is loaded as the
# ensure-profiles service's EnvironmentFile, and envsubst substitutes it into
# the generated profile at activation. The rendered profile (with the real key)
# is written to /run/NetworkManager/system-connections (tmpfs, 0600 root) — not
# /etc — and recreated from the agenix secret on every boot.
#
# autoconnect = false: this is a laptop; the tunnel comes up on demand from the
# applet. agenix installs via activation scripts, which finish before systemd
# starts NetworkManager-ensure-profiles at boot, so no unit ordering is needed.
{ config, ... }:

{
  # Decrypted to /run/agenix/wg-laptop-private (root, 0400). Content is a single
  # `WG_PRIVKEY=<key>` line so it can serve directly as the ensure-profiles
  # EnvironmentFile.
  age.secrets.wg-laptop-private.file = ../../secrets/wg-laptop-private.age;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets.wg-laptop-private.path ];

    profiles.wg-home = {
      connection = {
        id = "wg-home";
        type = "wireguard";
        interface-name = "wg0";
        autoconnect = false;
      };

      wireguard.private-key = "$WG_PRIVKEY";

      # Peer section name is literally `[wireguard-peer.<base64 pubkey>]`.
      "wireguard-peer.Ycpd8RYuz1rdByN6ACdyyOa3M/w+2RYsKdrhcz86jmw=" = {
        # DuckDNS hostname (router DDNS) so it survives a WAN IP change.
        endpoint = "hofland-home.duckdns.org:51820";
        # Full tunnel — all v4/v6 egresses through home.
        allowed-ips = "0.0.0.0/0;::/0;";
        persistent-keepalive = 25;
      };

      # dns-priority = -1 makes these servers exclusive while the tunnel is up,
      # so DNS can't leak to the underlying wifi's resolvers. Points at the
      # router (192.168.2.1 / …::1), i.e. onward to Blocky.
      ipv4 = {
        method = "manual";
        address1 = "192.168.2.3/32";
        dns = "192.168.2.1;";
        dns-priority = -1;
      };
      ipv6 = {
        method = "manual";
        address1 = "fd07:b913:ece8:b16b::3/128";
        dns = "fd07:b913:ece8:b16b::1;";
        dns-priority = -1;
      };
    };
  };
}
