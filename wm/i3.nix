{ config, pkgs, lib, ... }:

let
  modifier = config.xsession.windowManager.i3.config.modifier;
in {
  xsession.windowManager.i3 = {
    enable = true;
    package = pkgs.i3-gaps;
    config = {
      modifier = "Mod4";
      terminal = "alacritty";

      gaps = {
        inner = 10;
        outer = 5;
      };

      # Disable i3bar since we're using Polybar
      bars = [];

      # Keybindings
      keybindings = lib.mkOptionDefault {
        "${modifier}+Return" = "exec alacritty";
        "${modifier}+q" = "kill";
        "${modifier}+Shift+p" = "exec ${pkgs.dmenu}/bin/dmenu_run";
        "${modifier}+Shift+d" = "exec discord";
        "${modifier}+Shift+f" = "exec floorp";
        "${modifier}+Shift+n" = "exec $HOME/.local/bin/set-random-wallpaper.sh";
      };

      # Startup applications
      startup = [
        { command = "nm-applet"; }
        { command = "sleep 2 && blueman-applet"; }
        { command = "flameshot"; }
      ];
    };
  };
} 