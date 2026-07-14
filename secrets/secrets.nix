let
  primary = "age1k4xkk6zkzutch2jxg935wm55q92uvs4ql9czcgnpn6mrnpxs0ghqzgjvmd";
  # Home server host key (`cat /etc/ssh/ssh_host_ed25519_key.pub` on the
  # server). agenix accepts ssh-ed25519 keys directly; the server decrypts its
  # secrets at activation with the matching host private key.
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA3qLEFR4AVnU8/CaJY4E+r7vlrWh88bemK5Cn2/3oHp root@nixos";
in
{
  # Authorized SSH keys, decrypted on every host for connor's authorized_keys
  # (and the git user on the desktop). The server needs it too.
  "ssh-auth-keys.age".publicKeys = [
    primary
    server
  ];
  # Personal notes / master passwords (Bitwarden, Gmail, …). Readable by user connor at /run/agenix/passwords.
  "passwords.age".publicKeys = [ primary ];
  # Vaultwarden env file (ADMIN_TOKEN=...), decrypted on the server.
  "vaultwarden-env.age".publicKeys = [
    primary
    server
  ];
  # Cloudflare API token for Caddy's ACME DNS-01 challenge, decrypted on the
  # server as caddy's EnvironmentFile.
  "cloudflare-api-token.age".publicKeys = [
    primary
    server
  ];
}
