{ config, pkgs, ... }:

let
  mpdHost = "127.0.0.1";
  mpdPort = 6600;
  musicDir = "${config.home.homeDirectory}/Music";
in
{
  # MPD: local music daemon serving ~/Music. Runs as a user systemd service,
  # so it can reach the per-user PipeWire (pulse) socket for output.
  services.mpd = {
    enable = true;
    musicDirectory = musicDir;
    network = {
      listenAddress = mpdHost;
      port = mpdPort;
    };
    extraConfig = ''
      # PipeWire exposes a PulseAudio server; use its pulse output.
      audio_output {
        type "pulse"
        name "PipeWire"
      }
      # Rescan the library when files under music_directory change.
      auto_update "yes"
    '';
  };

  # Bridge MPD to MPRIS so playerctl and the XF86Audio media keys can drive it.
  services.mpd-mpris.enable = true;

  # beets: the import gatekeeper. Everything enters ~/Music through
  # `beet import`, which tags against MusicBrainz, fetches + embeds cover art
  # (so mpd/ncmpcpp/rmpc and Navidrome all see it), and files into a
  # consistent tree. beets is the only writer; mpd and the server's Navidrome
  # only ever read the result (Navidrome via the Syncthing copy of ~/Music).
  programs.beets = {
    enable = true;
    settings = {
      directory = musicDir;
      library = "${config.xdg.dataHome}/beets/library.db";

      import = {
        move = true; # move staged files into the library tree
        write = true; # write resolved tags back to the files
        # Only relevant to quiet imports (the `bi` alias passes -q for
        # hands-off singleton imports). chroma (below) fingerprint-matches
        # each track against AcoustID; strong matches are applied
        # automatically, and anything the fingerprint can't place is imported
        # "as-is" (keeping its existing / filename-derived tags) instead of
        # stopping to ask. Album imports (`ba`) omit -q and stay interactive.
        quiet_fallback = "asis";
      };

      plugins = [
        "chroma" # AcoustID acoustic-fingerprint matching (identifies songs by audio)
        "fromfilename" # derive artist/title from "Artist - Title" filenames when untagged
        "fetchart"
        "embedart"
        "lastgenre"
        "scrub"
        "duplicates"
      ];

      fetchart.auto = true;
      embedart.auto = true; # embed art so tag-reading clients show covers

      paths = {
        default = "$albumartist/$album%aunique{}/$track $title";
        singleton = "Non-Album/$artist/$title";
        comp = "Compilations/$album%aunique{}/$track $title";
      };
    };
  };

  # Terminal client.
  programs.ncmpcpp = {
    enable = true;
    mpdMusicDir = musicDir;
    settings = {
      mpd_host = mpdHost;
      mpd_port = mpdPort;
      playlist_display_mode = "columns";
      autocenter_mode = "yes";
      centered_cursor = "yes";
      # Directory browsing works even when files (e.g. .webm) lack tags.
      song_columns_list_format = "(20)[]{a} (30)[]{t|f} (30)[]{b}";
    };
  };

  # playerctl backs the media-key bindings in i3.nix. rmpc is a second TUI
  # client (inline album art) that coexists with ncmpcpp on the same daemon.
  # ffmpeg/yt-dlp back the staging workflow: yt-dlp grabs audio-only from a
  # URL, ffmpeg extracts/repackages audio, then `beet import` files it away.
  home.packages = [
    pkgs.playerctl
    pkgs.rmpc
    pkgs.ffmpeg
    pkgs.yt-dlp
  ];
}
