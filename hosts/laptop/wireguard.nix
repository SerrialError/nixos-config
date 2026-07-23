# WireGuard client to the home LAN (UniFi Dream Router 7's built-in server).
# Full tunnel: all v4/v6 traffic egresses through home, and DNS points at the
# router (192.168.2.1 / fd07:…::1) so name resolution goes through Blocky on
# the home server too.
#
# autostart = false: this is a laptop, the tunnel comes up on demand
# (`systemctl start wg-quick-wg0` / `wg-quick up wg0`). It also sidesteps a
# boot-time race with agenix — the private key at config.age.secrets.*.path
# doesn't exist until agenix.service has activated. If you ever flip this to
# true, add the ordering fix noted below so the unit waits for the key.
{ config, ... }:

{
  # Private key never touches the store — agenix decrypts it to a root-only
  # /run/agenix path that wg-quick reads at interface-up. No PresharedKey in the
  # exported .conf, so there's only this one secret.
  age.secrets.wg-laptop-private.file = ../../secrets/wg-laptop-private.age;

  networking.wg-quick.interfaces.wg0 = {
    address = [
      "192.168.2.3/32"
      "fd07:b913:ece8:b16b::3/128"
    ];
    dns = [
      "192.168.2.1"
      "fd07:b913:ece8:b16b::1"
    ];
    privateKeyFile = config.age.secrets.wg-laptop-private.path;
    autostart = false;

    peers = [
      {
        publicKey = "Ycpd8RYuz1rdByN6ACdyyOa3M/w+2RYsKdrhcz86jmw=";
        # Full tunnel — everything egresses through home.
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        # DuckDNS hostname (DDNS on the router) so the config survives a WAN
        # IP change; resolved fresh each time the interface comes up.
        endpoint = "hofland-home.duckdns.org:51820";
        # Laptop is usually behind NAT — keep the mapping alive.
        persistentKeepalive = 25;
      }
    ];
  };

  # Only relevant if autostart is ever set to true: the generated
  # wg-quick-wg0.service would otherwise start before agenix has written the
  # private key. Harmless to leave in place while autostart = false.
  systemd.services.wg-quick-wg0.after = [ "agenix.service" ];
}
