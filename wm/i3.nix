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

      # Window decoration settings
      window = {
        titlebar = false;
        border = 3;
        hideEdgeBorders = "none";
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
        { command = "picom --experimental-backends"; }
        { command = "lxappearance"; }  # Apply GTK theme
      ];
    };
  };

  # Picom compositor configuration
  services.picom = {
    enable = true;
    package = pkgs.picom;
    fade = true;
    fadeDelta = 5;
    fadeSteps = [ 0.03 0.03 ];
    shadow = true;
    shadowOffsets = [ (-10) (-10) ];
    shadowOpacity = 0.3;
    settings = {
      # Blur settings
      blur = {
        method = "dual_kawase";
        background = true;
        background-frame = true;
        background-fixed = true;
      };
      # Focus settings
      focus-exclude = [
        "class_g = 'Rofi'"
        "class_g = 'Polybar'"
      ];
      # Window type settings
      wintypes = {
        tooltip = { fade = true; shadow = true; opacity = 0.1; focus = true; };
        dock = { shadow = true; };
        dnd = { shadow = true; };
        popup_menu = { opacity = 0.95; };
        dropdown_menu = { opacity = 0.95; };
      };
      # Inactive window settings
      inactive-opacity = 0.95;
      inactive-dim = 0.4;
      # Active window settings
      active-opacity = 1.0;
      # Blur settings for unfocused windows
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Rofi'"
        "class_g = 'Polybar'"
      ];
    };
  };
} 
