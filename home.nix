{ config, inputs, pkgs, lib, ... }:

let
  modifier = config.xsession.windowManager.i3.config.modifier;
in {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ./features/alacritty.nix
  ];

  # Color scheme configuration
  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  # Nix configuration
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Home Manager configuration
  home.username = "connor";
  home.homeDirectory = "/home/connor";
  home.stateVersion = "24.05";

  # Custom vim plugins overlay
  nixpkgs = {
    overlays = [
      (final: prev: {
        vimPlugins = prev.vimPlugins // {
          own-onedark-nvim = prev.vimUtils.buildVimPlugin {
            pname = "own-onedark-nvim";
            version = "1.0.0";
            src = ./nvim/onedark.nvim;
          };
        };
      })
    ];
  }; 

  # X session and i3 configuration
  xsession.enable = true;
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

  # XDG user directories configuration
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      videos = "$HOME/Videos";
    };
  };

  # GTK theme configuration
  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.solarc-gtk-theme;
      name = "SolArc-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3";
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # QT theme configuration
  qt.enable = true;
  qt.platformTheme.name = "gtk";
  qt.style.name = "adwaita-dark";
  qt.style.package = pkgs.adwaita-qt;

  # File manager (lf) configuration
  programs.lf = {
    enable = true;
    commands = {
      dragon-out = ''%${pkgs.xdragon}/bin/xdragon -a -x "$fx"'';
      editor-open = ''$$EDITOR $f'';
      mkdir = ''
      ''${{
        printf "Directory Name: "
        read DIR
        mkdir $DIR
      }}
      '';
    };

    keybindings = {
      "\\\"" = "";
      o = "";
      c = "mkdir";
      "." = "set hidden!";
      "`" = "mark-load";
      "\\'" = "mark-load";
      "<enter>" = "open";
      do = "dragon-out";
      "g~" = "cd";
      gh = "cd";
      "g/" = "/";
      ee = "editor-open";
      V = ''$${pkgs.bat}/bin/bat --paging=always --theme=gruvbox "$f"'';
    };

    settings = {
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };

    extraConfig = 
    let 
      previewer = 
        pkgs.writeShellScriptBin "pv.sh" ''
        file=$1
        w=$2
        h=$3
        x=$4
        y=$5
        
        if [[ "$( ${pkgs.file}/bin/file -Lb --mime-type "$file")" =~ ^image ]]; then
            ${pkgs.kitty}/bin/kitty +kitten icat --silent --stdin no --transfer-mode file --place "''${w}x''${h}@''${x}x''${y}" "$file" < /dev/null > /dev/tty
            exit 1
        fi
        
        ${pkgs.pistol}/bin/pistol "$file"
      '';
      cleaner = pkgs.writeShellScriptBin "clean.sh" ''
        ${pkgs.kitty}/bin/kitty +kitten icat --clear --stdin no --silent --transfer-mode file < /dev/null > /dev/tty
      '';
    in
    ''
      set cleaner ${cleaner}/bin/clean.sh
      set previewer ${previewer}/bin/pv.sh
    '';
  };

  # PDF viewer configuration
  programs.zathura = {
    enable = true;
  };

  # Python plotting library configuration
  programs.matplotlib = {
    enable = true;
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName  = "Serrial Error";
    userEmail = "serrialerror@outlook.com";
  };

  # Required packages
  home.packages = with pkgs; [
    protonup
    feh  # For wallpaper management
    brightnessctl  # For backlight control
    pavucontrol    # For volume control
    nerd-fonts.jetbrains-mono  # For JetBrains Mono Nerd Font
  ];

  # Create and set up the wallpaper script
  home.file.".local/bin/set-random-wallpaper.sh" = {
    text = ''
      #!/usr/bin/env bash

      # Get a random wallpaper from the wallpapers directory
      WALLPAPER_DIR="$HOME/Pictures/wallpapers"
      WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)

      # Set the wallpaper using feh
      if [ -n "$WALLPAPER" ]; then
          feh --bg-fill "$WALLPAPER"
      fi
    '';
    executable = true;
  };

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
        interval = "1";  # Changed from 0.5 to "1" to fix type error
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

  # Run the wallpaper script when X session starts
  xsession.initExtra = ''
    $HOME/.local/bin/set-random-wallpaper.sh
  '';

  # Steam configuration
  home.file.".local/share/Steam/steamapps/common" = {
    source = config.lib.file.mkOutOfStoreSymlink "/mnt/steam/steamapps/common";
    recursive = true;
  };

  home.file.".steam/root/compatibilitytools.d" = {
    source = config.lib.file.mkOutOfStoreSymlink "/mnt/steam/compatibilitytools.d";
    recursive = true;
  };

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };
}

