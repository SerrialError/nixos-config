{ config, inputs, pkgs, lib, ... }:

{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ./features/alacritty.nix
    ./features/wm/i3.nix
    ./features/wm/polybar.nix
    ./features/desktop/gtk.nix
    ./features/desktop/lf.nix
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

  # X session configuration
  xsession.enable = true;

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

