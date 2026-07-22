# betterlockscreen + xss-lock, laptop-only. Locks the X session before the
# machine sleeps (lid-close/suspend) and after an idle timeout, so the laptop
# always demands the password on resume — important since it goes out in public.
#
# Enabled only on the laptop (via osConfig, the same host switch home.nix uses
# for Syncthing): the desktop is a stationary LAN-trusted workstation and does
# not want idle-locking mid-movie.
{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  isLaptop = osConfig.networking.hostName == "laptop";
in
{
  config = lib.mkIf isLaptop {
    # home-manager's screen-locker wires up two user services bound to
    # graphical-session.target: xss-lock (registers a logind sleep inhibitor so
    # the lock runs *before* suspend and the sleep lock is handed off with
    # --transfer-sleep-lock) and xautolock (idle timer). lockCmd is what both
    # trigger. betterlockscreen --lock renders from the cache that
    # set-random-wallpaper.sh refreshes (`betterlockscreen -u`) on every
    # wallpaper change, so the lock image tracks the current wallpaper.
    services.screen-locker = {
      enable = true;
      inactiveInterval = 10; # minutes of idle before auto-lock
      lockCmd = "${pkgs.betterlockscreen}/bin/betterlockscreen --lock dim";
      xautolock = {
        enable = true;
        detectSleep = true; # reset the idle timer on resume
      };
      xss-lock.extraOptions = [ "--transfer-sleep-lock" ];
    };

    home.packages = [ pkgs.betterlockscreen ];
  };
}
