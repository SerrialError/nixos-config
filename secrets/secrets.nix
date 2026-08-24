let
  primary = "age1k4xkk6zkzutch2jxg935wm55q92uvs4ql9czcgnpn6mrnpxs0ghqzgjvmd";
  # Home server host key (`cat /etc/ssh/ssh_host_ed25519_key.pub` on the
  # server). agenix accepts ssh-ed25519 keys directly; the server decrypts its
  # secrets at activation with the matching host private key.
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA3qLEFR4AVnU8/CaJY4E+r7vlrWh88bemK5Cn2/3oHp root@nixos";
  # Laptop host key (`cat /etc/ssh/ssh_host_ed25519_key.pub` on the laptop).
  # agenix decrypts the laptop's secrets at activation with the matching host
  # private key.
  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnrjB/+1+sKIZKgyVKkZ104p1ok5GCSH5lkPTPfAmEf root@nixos";
in
{
  # Authorized SSH keys, decrypted on every host for connor's authorized_keys
  # (and the git user on the desktop). The server needs it too.
  "ssh-auth-keys.age".publicKeys = [
    primary
    server
    laptop
  ];
  # Personal notes / master passwords (Bitwarden, Gmail, …). Readable by user
  # connor at /run/agenix/passwords on both graphical hosts (desktop + laptop).
  "passwords.age".publicKeys = [
    primary
    laptop
  ];
  # Shared GitHub SSH auth key (ed25519 private key). One identity for every
  # graphical host so cloning/pushing works identically on desktop and laptop —
  # no per-device key to register or lose. Decrypted for connor and used as the
  # ssh IdentityFile for github.com (see profiles/desktop.nix).
  "github-ssh.age".publicKeys = [
    primary
    laptop
  ];
  # WireGuard client private key for the laptop's wg0 interface (full tunnel to
  # the home LAN). Decrypted on the laptop, read by wg-quick as root.
  "wg-laptop-private.age".publicKeys = [
    primary
    laptop
  ];
  # Vaultwarden env file (ADMIN_TOKEN=<argon2id hash>), decrypted on the server.
  "vaultwarden-env.age".publicKeys = [
    primary
    server
  ];
  # Plaintext of the Vaultwarden admin-panel password (its argon2id hash lives
  # in vaultwarden-env). Desktop-only: never deployed to a host, kept only so
  # the login password is recoverable via `agenix -d` / `age -d`.
  "vaultwarden-admin-password.age".publicKeys = [ primary ];
  # Cloudflare API token for Caddy's ACME DNS-01 challenge, decrypted on the
  # server as caddy's EnvironmentFile.
  "cloudflare-api-token.age".publicKeys = [
    primary
    server
  ];
  # Gatus environment file: NTFY_URL / NTFY_TOPIC / NTFY_TOKEN for alerting,
  # interpolated into the Gatus config. Decrypted on the server.
  "gatus-env.age".publicKeys = [
    primary
    server
  ];
  # healthchecks.io ping URL (a capability URL) for the dead-man's-switch timer.
  # Decrypted on the server.
  "healthchecks-url.age".publicKeys = [
    primary
    server
  ];
  # Taskwarrior TaskChampion sync secret: a single
  # `sync.encryption_secret=<value>` line, decrypted on the desktop and
  # included by the taskrc. The same secret is typed into the phone's Taskchamp
  # app. Desktop-only — the server only ever stores ciphertext, so the shared
  # key never needs to live there.
  "task-sync-secret.age".publicKeys = [ primary ];
}
