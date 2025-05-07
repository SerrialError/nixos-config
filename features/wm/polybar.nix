{ config, pkgs, ... }:

{
  # Required packages
  home.packages = with pkgs; [
    brightnessctl  # For backlight control
    pavucontrol    # For volume control
    nerd-fonts.jetbrains-mono  # For JetBrains Mono Nerd Font
  ];

  # Polybar configuration
  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3Support = true;
      pulseSupport = true;
      alsaSupport = true;
      mpdSupport = true;
      githubSupport = true;
    };
    script = "polybar main &";
    config = {
      # Colors
      "colors" = {
        background = "#282A2E";
        background-alt = "#373B41";
        foreground = "#C5C8C6";
        primary = "#F0C674";
        secondary = "#8ABEB7";
        alert = "#A54242";
        disabled = "#707880";
      };

      # Main bar
      "bar/main" = {
        width = "100%";
        height = "24pt";
        radius = 9;
        background = "\${colors.background}";
        foreground = "\${colors.foreground}";
        line-size = "3pt";
        border-size = "4pt";
        border-color = "#00000000";
        padding-left = 0;
        padding-right = 1;
        module-margin = 1;
        separator = "|";
        separator-foreground = "\${colors.disabled}";
        font-0 = "JetBrainsMono Nerd Font:size=10;2";
        modules-left = "systray xworkspaces xwindow";
        modules-right = "battery temperature pulseaudio backlight date";
        cursor-click = "pointer";
        cursor-scroll = "ns-resize";
        enable-ipc = true;
      };

      # Modules
      "module/systray" = {
        type = "internal/tray";
        format-margin = "8px";
        tray-spacing = "8px";
      };

      "module/xworkspaces" = {
        type = "internal/xworkspaces";
        label-active = "%name%";
        label-active-background = "\${colors.background-alt}";
        label-active-underline = "\${colors.primary}";
        label-active-padding = 1;
        label-occupied = "%name%";
        label-occupied-padding = 1;
        label-urgent = "%name%";
        label-urgent-background = "\${colors.alert}";
        label-urgent-padding = 1;
        label-empty = "%name%";
        label-empty-foreground = "\${colors.disabled}";
        label-empty-padding = 1;
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title:0:60:...%";
      };

      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        format-volume-prefix = "VOL ";
        format-volume-prefix-foreground = "\${colors.primary}";
        format-volume = "<label-volume>";
        label-volume = "%percentage%%";
        label-muted = "muted";
        label-muted-foreground = "\${colors.disabled}";
      };

      "module/battery" = {
        type = "internal/battery";
        format-bat = "<label-bat>";
        label-bat = "%percentage%%";
        format-charging = "<label-charging>";
        label-charging = "Charging %percentage%%";
        format-low = "<label-low>";
        label-low = "BATTERY LOW %percentage%%";
        low-at = 20;
        battery = "BAT0";
        adapter = "ADP0";
        poll-interval = 5;
      };

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%H:%M";
        date-alt = "%Y-%m-%d %H:%M:%S";
        label = "%date%";
        label-foreground = "\${colors.primary}";
      };

      "module/backlight" = {
        type = "internal/backlight";
        card = "intel_backlight";
        format = "<label>";
        label = "%percentage%%";
        label-foreground = "\${colors.foreground}";
      };

      "module/temperature" = {
        type = "internal/temperature";
        interval = "1";
        thermal-zone = 0;
        zone-type = "x86_pkg_temp";
        hwmon-path = "/sys/devices/platform/coretemp.0/hwmon/hwmon3/temp1_input";
        base-temperature = 20;
        warn-temperature = 60;
        label = "%temperature-f%";
      };

      "module/mpd" = {
        type = "internal/mpd";
        host = "127.0.0.1";
        port = 6600;
        interval = 2;
        label-song = "%title%";
      };
    };
  };

  # Create brightness script for Polybar
  home.file.".config/polybar/scripts/brightnes-onscroll.sh" = {
    text = ''
      #!/usr/bin/env bash
      
      # Get current brightness
      current=$(brightnessctl g)
      max=$(brightnessctl m)
      
      # Calculate percentage
      percent=$((current * 100 / max))
      
      # Output with icon
      if [ "$percent" -gt 80 ]; then
          echo "󰃠 $percent%"
      elif [ "$percent" -gt 50 ]; then
          echo "󰃟 $percent%"
      elif [ "$percent" -gt 20 ]; then
          echo "󰃞 $percent%"
      else
          echo "󰃝 $percent%"
      fi
    '';
    executable = true;
  };
} 