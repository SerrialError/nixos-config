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

  # playerctl backs the media-key bindings in i3.nix.
  home.packages = [ pkgs.playerctl ];
}
