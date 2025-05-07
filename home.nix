{ config, inputs, pkgs, lib, ... }:

let
  inherit (builtins) readFile;
  inherit (lib) fileContents;
  configDir = builtins.path {
    path = ./.;
    name = "home-config";
  };
in {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    (import ./alacritty.nix)
    (import ./wm/i3.nix)
    (import ./wm/polybar.nix)
    (import ./desktop/gtk.nix)
    (import ./desktop/lf.nix)
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
  home.stateVersion = "25.05";

  # Neovim configuration
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
    extraPython3Packages = ps: with ps; [
      pynvim
      black
      isort
      flake8
    ];
    extraPackages = with pkgs; [
      # Clipboard support
      xclip
      wl-clipboard
    ];
    extraLuaConfig = ''
      -- Clipboard settings
      vim.opt.clipboard = 'unnamedplus'
      vim.keymap.set('n', 'y', '"+y')
      vim.keymap.set('v', 'y', '"+y')
      vim.keymap.set('n', 'Y', '"+Y')
      vim.keymap.set('n', 'p', '"+p')
      vim.keymap.set('v', 'p', '"+p')
      vim.keymap.set('n', 'P', '"+P')
    '';
    plugins = with pkgs.vimPlugins; [
      # LSP and Completion
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      lspkind-nvim
      nvim-lspconfig
      luasnip
      friendly-snippets
      neodev-nvim
      
      # Telescope
      telescope-nvim
      plenary-nvim
      telescope-fzf-native-nvim
      
      # Treesitter
      nvim-treesitter
      nvim-treesitter-textobjects
      
      # UI
      lualine-nvim
      nvim-web-devicons
      bufferline-nvim
      nvim-colorizer-lua
      
      # Git
      gitsigns-nvim
      
      # Utilities
      nvim-autopairs
      nvim-ts-context-commentstring
      comment-nvim
      vim-surround
      vim-repeat
      
      # Themes
      onedark-nvim
      gruvbox-nvim
    ];
  };

  # Link your Neovim configuration
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

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
    # Development tools
    nil       # Nix language server
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    rust-analyzer
    lua-language-server
    python3Packages.python-lsp-server
    clang-tools
    gopls
    haskell-language-server
    texlab
    zls

    # System utilities
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
    XDG_SESSION_TYPE = "x11";  # Ensure X11 clipboard is used
  };

  # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };
}

