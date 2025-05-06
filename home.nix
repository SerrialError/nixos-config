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
    })  # Add polybar with all necessary features
    jetbrains-mono  # Font for polybar
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
      background = #282828
      background-alt = #3c3836
      foreground = #ebdbb2
      foreground-alt = #a89984
      primary = #b8bb26
      secondary = #689d6a
      alert = #fb4934
      network-connected = #9b78dd
      network-disconnected = #FF0000

      [bar/main]
      monitor = HDMI-0
      width = 100%
      height = 24
      offset-x = 0
      offset-y = 0
      radius = 0
      fixed-center = true
      background = #282828
      foreground = #ebdbb2
      border-size = 0
      border-color = #00000000
      padding-left = 1
      padding-right = 1
      module-margin-left = 1
      module-margin-right = 1
      font-0 = "JetBrainsMono Nerd Font:size=10;3"
      modules-left = i3
      modules-center = date
      modules-right = cpu memory pulseaudio network

      [module/tray]
      type = internal/tray
      tray-size = 16
      tray-spacing = 2
      tray-background = #282828
      tray-offset-x = 0
      tray-offset-y = 0
      tray-padding = 2
      tray-maxsize = 16
      tray-scale = 1.0
      tray-position = right

      [module/i3]
      type = internal/i3
      format = <label-state> <label-mode>
      label-mode = %mode%
      label-mode-padding = 2
      label-mode-foreground = #000
      label-mode-background = #b8bb26

      label-focused = %index%
      label-focused-background = #3c3836
      label-focused-underline = #b8bb26
      label-focused-padding = 2
      label-focused-font = 1

      label-unfocused = %index%
      label-unfocused-padding = 2
      label-unfocused-font = 1

      label-visible = %index%
      label-visible-background = #3c3836
      label-visible-underline = #b8bb26
      label-visible-padding = 2
      label-visible-font = 1

      label-urgent = %index%
      label-urgent-background = #fb4934
      label-urgent-padding = 2
      label-urgent-font = 1

      # Enable click handlers
      enable-click = true
      enable-scroll = true

      # Enable wrapping of workspace names
      wrap-scroll = false

      # Enable fuzzy matching on workspace names
      fuzzy-match = true

      [module/date]
      type = internal/date
      interval = 1.0
      date = %Y-%m-%d%
      time = %H:%M
      format = <label>
      label = %date% %time%
      label-foreground = #a89984

      [module/cpu]
      type = internal/cpu
      interval = 1
      format-prefix = "CPU "
      format-prefix-foreground = #a89984
      format-underline = #f90000
      label = %percentage:2%%

      [module/memory]
      type = internal/memory
      interval = 1
      format-prefix = "RAM "
      format-prefix-foreground = #a89984
      format-underline = #4bffdc
      label = %percentage_used:2%%

      [module/pulseaudio]
      type = internal/pulseaudio
      format-volume-prefix = "VOL "
      format-volume-prefix-foreground = #a89984
      format-volume-underline = #9b78dd
      label-volume = %percentage%%
      label-muted = muted
      label-muted-foreground = #666

      [module/network]
      type = internal/network
      interface-type = wireless
      interval = 3.0
      format-connected = <label-connected>
      format-disconnected = <label-disconnected>
      label-connected = %{F#9b78dd}%{F-} %essid%
      label-disconnected = %{F#FF0000}%{F-}offline
      label-disconnected-foreground = #a89984
    '';
  };

  # Create Polybar launch script
  home.file.".config/polybar/launch.sh" = {
    text = ''
      #!/usr/bin/env bash

      # Terminate already running bar instances
      pkill -x polybar

      # Wait until the processes have been shut down
      while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

      # Launch Polybar
      polybar main &
    '';
    executable = true;
  };

  # Run the wallpaper script and Polybar when X session starts
  xsession.initExtra = ''
    $HOME/.local/bin/set-random-wallpaper.sh
    $HOME/.config/polybar/launch.sh
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


  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

