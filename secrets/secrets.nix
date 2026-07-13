let
  primary = "age1k4xkk6zkzutch2jxg935wm55q92uvs4ql9czcgnpn6mrnpxs0ghqzgjvmd";
  # TODO(bootstrap): after installing NixOS on the server, paste its host key
  # here (`cat /etc/ssh/ssh_host_ed25519_key.pub` on the server — agenix
  # accepts ssh-ed25519 keys directly), add `server` to the publicKeys lists
  # below, then rekey from this directory: `agenix -r`.
  # server = "ssh-ed25519 AAAA... root@server";
in
{
  # Once the server key exists, this needs it too (the server decrypts it at
  # activation for authorized_keys): publicKeys = [ primary server ];
  "ssh-auth-keys.age".publicKeys = [ primary ];
  # Personal notes / master passwords (Bitwarden, Gmail, …). Readable by user connor at /run/agenix/passwords.
  "passwords.age".publicKeys = [ primary ];
  # Vaultwarden env file (ADMIN_TOKEN=...). Create with `agenix -e
  # vaultwarden-env.age` after adding the server key; then uncomment the
  # age.secrets block in hosts/server/default.nix.
  "vaultwarden-env.age".publicKeys = [ primary ];
}
