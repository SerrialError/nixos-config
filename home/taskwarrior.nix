{ pkgs, ... }:

{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;

    config = {
      news.version = "3.4.0";
      weekstart = "monday";
      dateformat = "Y-M-D";
      verbose = "blank,header,footnote,label,new-id,affected,edit,special,project,sync";

      # TaskChampion sync against the home server (reached directly on the LAN
      # here; the phone reaches it over WireGuard). The client_id identifies the
      # shared task list, so the phone's Taskchamp uses this SAME id (and the
      # same encryption_secret). URL + client_id are not secret, so they can
      # live in the (public) store-backed config.
      sync.server.url = "http://192.168.1.245:10222";
      sync.server.client_id = "5a1322be-3f3a-4354-a430-90b9325ddb41";
    };

    # The shared sync.encryption_secret is sensitive and this repo is public, so
    # it must NOT go through `config` (home-manager writes that into the
    # world-readable nix store). agenix decrypts it to a connor-readable runtime
    # path; include that so the real taskrc picks it up (nested includes work).
    extraConfig = ''
      include /run/agenix/task-sync-secret
    '';
  };

  home.packages = [
    pkgs.taskwarrior-tui
  ];
}
