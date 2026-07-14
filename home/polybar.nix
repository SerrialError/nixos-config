{ config, pkgs, ... }:

let
  # Wrap the raw script so it runs under the polybar systemd user service,
  # which has a minimal PATH (no `bash`/`jq`/`curl`). writeShellApplication
  # gives it an absolute bash shebang and puts its deps on PATH.
  polybar-updates = pkgs.writeShellApplication {
    name = "polybar-updates";
    runtimeInputs = with pkgs; [
      jq
      curl
    ];
    text = builtins.readFile ../scripts/polybar-updates.sh;
  };
  # Calls nvidia-smi by absolute system-profile path, so no runtimeInputs.
  polybar-gputemp = pkgs.writeShellApplication {
    name = "polybar-gputemp";
    text = builtins.readFile ../scripts/polybar-gputemp.sh;
  };
in
{
  # Required packages
  home.packages = with pkgs; [
    pavucontrol # For volume control
    nerd-fonts.jetbrains-mono # For JetBrains Mono Nerd Font
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
        modules-right = "mpd updates temperature gputemp pulseaudio date";
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

      "module/date" = {
        type = "internal/date";
        interval = 1;
        date = "%H:%M";
        date-alt = "%Y-%m-%d %H:%M:%S";
        label = "%date%";
        label-foreground = "\${colors.primary}";
      };

      "module/temperature" = {
        type = "internal/temperature";
        interval = "1";
        # thermal_zone2 is the x86_pkg_temp (CPU package) zone on this host.
        # hwmon indices are unstable across boots, so drive it off the zone
        # rather than a hardcoded /sys/.../hwmonN path.
        thermal-zone = 2;
        zone-type = "x86_pkg_temp";
        base-temperature = 20;
        warn-temperature = 60;
        # Pin both normal and warn labels to Fahrenheit — label-warn defaults
        # to Celsius, which caused the F/C flip once the CPU crossed 60C.
        label = "CPU %temperature-f%";
        label-warn = "CPU %temperature-f%";
      };

      "module/gputemp" = {
        type = "custom/script";
        exec = "${polybar-gputemp}/bin/polybar-gputemp";
        interval = 5;
      };

      # Shows " updates" when the nixpkgs channel is ahead of flake.lock,
      # or a green checkmark when up to date. Polled hourly; click to re-check.
      "module/updates" = {
        type = "custom/script";
        exec = "${polybar-updates}/bin/polybar-updates";
        interval = 3600;
        click-left = "${polybar-updates}/bin/polybar-updates";
      };

      "module/mpd" = {
        type = "internal/mpd";
        host = "127.0.0.1";
        port = 6600;
        interval = 2;
        # Falls back to the filename when a track has no tags (e.g. .webm).
        label-song = "%artist% - %title%";
        label-song-maxlen = 45;
        label-song-ellipsis = true;
        format-online = "<label-song>  <toggle> <icon-prev> <icon-next>";
        format-online-prefix = " ";
        format-online-prefix-foreground = "\${colors.primary}";
        icon-play = "";
        icon-pause = "";
        icon-prev = "";
        icon-next = "";
        label-offline = "";
      };
    };
  };
}
