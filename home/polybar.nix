{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:

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

  # The desktop and laptop share this bar; a few modules are host-specific.
  # The laptop swaps the NVIDIA gputemp module for battery + Wi-Fi indicators.
  isLaptop = osConfig.networking.hostName == "laptop";
  modulesRight =
    if isLaptop then
      "mpd updates temperature pulseaudio network battery date"
    else
      "mpd updates temperature gputemp pulseaudio date";
  # polybar reads the CPU temperature by thermal-zone index, and x86_pkg_temp
  # sits at a different index on each machine (zone 2 on the desktop, zone 7 on
  # the laptop), so the index must be chosen per host.
  cpuThermalZone = if isLaptop then 7 else 2;
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
        modules-right = modulesRight;
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
        # x86_pkg_temp (CPU package) zone; its index differs per host, so it is
        # set via cpuThermalZone above. hwmon indices are unstable across boots,
        # so drive it off the thermal zone rather than a hardcoded hwmonN path.
        thermal-zone = cpuThermalZone;
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

      # Shows yellow "Updates Available" when the nixpkgs channel is ahead of
      # flake.lock, or green "Up to Date" when it matches. Only tracks the
      # nixpkgs input, not the other flake inputs. Polled hourly; click to
      # re-check.
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
    }
    // lib.optionalAttrs isLaptop {
      # Laptop-only hardware indicators. BAT0/ADP0 and the wlp1s0 Wi-Fi radio
      # don't exist on the desktop (wired + no battery), so these modules are
      # only defined — and only referenced in modules-right — on the laptop.
      "module/battery" = {
        type = "internal/battery";
        battery = "BAT0";
        adapter = "ADP0";
        full-at = 99;
        poll-interval = 5;
        format-charging = "<animation-charging> <label-charging>";
        format-discharging = "<ramp-capacity> <label-discharging>";
        format-full = "<ramp-capacity> <label-full>";
        label-charging = "%percentage%%";
        label-discharging = "%percentage%%";
        label-full = "%percentage%%";
        ramp-capacity-0 = "";
        ramp-capacity-1 = "";
        ramp-capacity-2 = "";
        ramp-capacity-3 = "";
        ramp-capacity-4 = "";
        ramp-capacity-0-foreground = "\${colors.alert}";
        animation-charging-0 = "";
        animation-charging-1 = "";
        animation-charging-2 = "";
        animation-charging-3 = "";
        animation-charging-4 = "";
        animation-charging-framerate = 750;
      };
      "module/network" = {
        type = "internal/network";
        interface = "wlp1s0";
        interface-type = "wireless";
        interval = 5;
        format-connected = "<ramp-signal> <label-connected>";
        label-connected = "%essid%";
        format-disconnected = "<label-disconnected>";
        label-disconnected = "off";
        label-disconnected-foreground = "\${colors.disabled}";
        ramp-signal-0 = "󰤯";
        ramp-signal-1 = "󰤟";
        ramp-signal-2 = "󰤢";
        ramp-signal-3 = "󰤥";
        ramp-signal-4 = "󰤨";
      };
    };
  };
}
