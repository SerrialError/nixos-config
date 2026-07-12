let
  primary = "age1k4xkk6zkzutch2jxg935wm55q92uvs4ql9czcgnpn6mrnpxs0ghqzgjvmd";
in
{
  "ssh-auth-keys.age".publicKeys = [ primary ];
  # Personal notes / master passwords (Bitwarden, Gmail, …). Readable by user connor at /run/agenix/passwords.
  "passwords.age".publicKeys = [ primary ];
}
