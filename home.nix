{ config, inputs, pkgs, lib, ... }:

let
  modifier = config.xsession.windowManager.i3.config.modifier;
in {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ./features/alacritty.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "connor";
  home.homeDirectory = "/home/connor";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.
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
  # Enable X session management
  xsession.enable = true;

  # Configuration for the i3 window manager
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

      # Disable i3bar
      bars = [];

      # Extend or override default keybindings
      keybindings = lib.mkOptionDefault {
        "${modifier}+Return" = "exec alacritty";
        "${modifier}+q" = "kill";
        "${modifier}+Shift+p" = "exec ${pkgs.dmenu}/bin/dmenu_run";
        "${modifier}+Shift+d" = "exec discord";
        "${modifier}+Shift+f" = "exec floorp";
      };
    };
  };

  xdg.configFile."lf/icons".source = ./icons;
  gtk.enable = true;
  gtk.iconTheme.package = pkgs.solarc-gtk-theme;
  gtk.iconTheme.name = "SolArc-Dark";
  gtk.cursorTheme.package = pkgs.bibata-cursors;
  gtk.cursorTheme.name = "Bibata-Modern-Ice";
  gtk.theme.package = pkgs.adw-gtk3;
  gtk.theme.name = "adw-gtk3";
  qt.enable = true;
  qt.platformTheme.name = "gtk";
  qt.style.name = "adwaita-dark";
  qt.style.package = pkgs.adwaita-qt;

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

      # ...
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
  programs.zathura = {
    enable = true;
  };
  programs.matplotlib = {
    enable = true;
  };
  programs.git = {
    enable = true;
    userName  = "Serrial Error";
    userEmail = "serrialerror@outlook.com";
  };
  programs.java = {
    enable = true;
  };
  programs.neovim = 
  let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in
  {
    enable = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    extraPackages = with pkgs; [
      lua-language-server
      nil

      xclip
      wl-clipboard
    ];

    plugins = with pkgs.vimPlugins; [

      {
        plugin = nvim-lspconfig;
        config = toLuaFile ./nvim/plugin/lsp.lua;
      }

      {
        plugin = comment-nvim;
        config = toLua "require(\"Comment\").setup()";
      }

      {
        plugin = gruvbox-nvim;
        config = "colorscheme gruvbox";
      }

      neodev-nvim

      nvim-cmp 
      {
        plugin = nvim-cmp;
        config = toLuaFile ./nvim/plugin/cmp.lua;
      }

      {
        plugin = telescope-nvim;
        config = toLuaFile ./nvim/plugin/telescope.lua;
      }

      telescope-fzf-native-nvim

      cmp_luasnip
      cmp-nvim-lsp

      luasnip
      friendly-snippets


      lualine-nvim
      nvim-web-devicons

      {
        plugin = (nvim-treesitter.withPlugins (p: [
          p.tree-sitter-nix
          p.tree-sitter-vim
          p.tree-sitter-bash
          p.tree-sitter-lua
          p.tree-sitter-python
          p.tree-sitter-json
        ]));
        config = toLuaFile ./nvim/plugin/treesitter.lua;
      }

      vim-nix

      # {
      #   plugin = vimPlugins.own-onedark-nvim;
      #   config = "colorscheme onedark";
      # }
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./nvim/options.lua}
    '';

    # extraLuaConfig = ''
    #   ${builtins.readFile ./nvim/options.lua}
    #   ${builtins.readFile ./nvim/plugin/lsp.lua}
    #   ${builtins.readFile ./nvim/plugin/cmp.lua}
    #   ${builtins.readFile ./nvim/plugin/telescope.lua}
    #   ${builtins.readFile ./nvim/plugin/treesitter.lua}
    #   ${builtins.readFile ./nvim/plugin/other.lua}
    # '';
  };



  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    protonup
    feh  # Add feh for wallpaper management
    (polybar.override {
      i3Support = true;
      pulseSupport = true;
      alsaSupport = true;
      mpdSupport = true;
      githubSupport = true;
    })
    brightnessctl  # For backlight control
    pavucontrol    # For volume control
    nerd-fonts.jetbrains-mono  # For CaskaydiaCove Nerd Font
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = ./dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

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
  home.file.".config/polybar/config.ini" = {
    text = ''
      [colors]
      background = #282A2E
      background-alt = #373B41
      foreground = #C5C8C6
      primary = #F0C674
      secondary = #8ABEB7
      alert = #A54242
      disabled = #707880

      [bar/main]
      width = 100%
      height = 24pt
      radius = 9
      background = ''${colors.background}
      foreground = ''${colors.foreground}
      line-size = 3pt
      border-size = 4pt
      border-color = #00000000
      padding-left = 0
      padding-right = 1
      module-margin = 1
      separator = |
      separator-foreground = ''${colors.disabled}
      font-0 = "JetBrainsMono Nerd Font:size=10;2"
      modules-left = systray xworkspaces xwindow
      modules-right = battery temperature pulseaudio backlight date
      cursor-click = pointer
      cursor-scroll = ns-resize
      enable-ipc = true

      [module/systray]
      type = internal/tray
      format-margin = 8px
      tray-spacing = 8px

      [module/xworkspaces]
      type = internal/xworkspaces
      label-active = %name%
      label-active-background = ''${colors.background-alt}
      label-active-underline = ''${colors.primary}
      label-active-padding = 1
      label-occupied = %name%
      label-occupied-padding = 1
      label-urgent = %name%
      label-urgent-background = ''${colors.alert}
      label-urgent-padding = 1
      label-empty = %name%
      label-empty-foreground = ''${colors.disabled}
      label-empty-padding = 1

      [module/xwindow]
      type = internal/xwindow
      label = %title:0:60:...%

      [module/pulseaudio]
      type = internal/pulseaudio
      format-volume-prefix = "VOL "
      format-volume-prefix-foreground = ''${colors.primary}
      format-volume = <label-volume>
      label-volume = %percentage%%
      label-muted = muted
      label-muted-foreground = ''${colors.disabled}

      [module/battery]
      type = internal/battery
      format-bat = <label-bat>
      label-bat = %percentage%%
      format-charging = <label-charging>
      label-charging = Charging %percentage%%
      format-low = <label-low>
      label-low = BATTERY LOW %percentage%%
      low-at = 20
      battery = BAT0
      adapter = ADP0
      poll-interval = 5

      [module/date]
      type = internal/date
      interval = 1
      date = %H:%M
      date-alt = %Y-%m-%d %H:%M:%S
      label = %date%
      label-foreground = ''${colors.primary}

      [module/backlight]
      type = internal/backlight
      card = intel_backlight
      format = <label>
      label = %percentage%%
      label-foreground = ''${colors.foreground}

      [module/temperature]
      type = internal/temperature
      interval = 0.5
      thermal-zone = 0
      zone-type = x86_pkg_temp
      hwmon-path = /sys/devices/platform/coretemp.0/hwmon/hwmon3/temp1_input
      base-temperature = 20
      warn-temperature = 60
      label = %temperature-f%

      [module/mpd]
      type = internal/mpd
      host = 127.0.0.1
      port = 6600
      interval = 2
      label-song = %title%
    '';
  };

  # Create Polybar launch script
  home.file.".config/polybar/launch.sh" = {
    text = ''
      #!/usr/bin/env bash

      # Terminate already running bar instances
      killall -q polybar || true

      # Wait until the processes have been shut down
      while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

      # Launch Polybar
      polybar main &
    '';
    executable = true;
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

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/connor/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    STEAM_EXTRA_COMPAT_TOOLS_PATHS =
      "\${HOME}/.steam/root/compatibilitytools.d";
  };

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
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

