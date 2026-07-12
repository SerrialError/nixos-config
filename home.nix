{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

let
  inherit (builtins) readFile;
  inherit (lib) fileContents;
  configDir = builtins.path {
    path = ./.;
    name = "home-config";
  };
in
{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.nvf.homeManagerModules.default
    (import ./alacritty.nix)
    (import ./wm/i3.nix)
    (import ./wm/polybar.nix)
    (import ./desktop/gtk.nix)
    (import ./desktop/lf.nix)
    ./home
  ];

  # Color scheme configuration
  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  # Nix configuration
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  # nixpkgs config (allowUnfree, insecure permits, overlays) comes from the
  # system via home-manager.useGlobalPkgs in configuration.nix
  # Home Manager configuration
  # home.username = "connor";
  # home.homeDirectory = "/home/connor";
  home.stateVersion = "25.11";
  home.file."bin/element".text = ''
    	#!/usr/bin/env bash
      	eval $(gnome-keyring-daemon --start --components=secrets)
      	export GNOME_KEYRING_CONTROL
      	export DBUS_SESSION_BUS_ADDRESS
      	${pkgs.element-desktop}/bin/element-desktop "$@"
  '';

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

  # zsh is the primary interactive shell (see users.users.connor.shell).
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true; # fish-style inline suggestions
    syntaxHighlighting.enable = true; # fish-style command highlighting
    enableCompletion = true;
    autocd = true;
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };
    shellAliases = {
      # rebuild, piping the build log through nix-output-monitor
      nrs = "sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure |& nom";
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --git --group-directories-first";
      la = "eza -la --icons --git --group-directories-first";
      lt = "eza --tree --icons --level=2";
      cat = "bat";
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";
    };
    # agenix personal password notes (see age.secrets.passwords)
    #   pw  — view deployed secret at /run/agenix/passwords
    #   pws — decrypt passwords.age to stdout (no rebuild needed)
    #   pwe — edit the encrypted secret (then nrs to redeploy)
    initContent = ''
      pw()  { bat /run/agenix/passwords; }
      pws() {
        agenix -d "$HOME/git/nixos-config/secrets/passwords.age" \
          -i "$HOME/.config/sops/age/keys.txt"
      }
      pwe() {
        (
          cd "$HOME/git/nixos-config/secrets" || return 1
          RULES=./secrets.nix agenix -e passwords.age \
            -i "$HOME/.config/sops/age/keys.txt"
        ) && echo "Saved. Run 'nrs' to refresh /run/agenix/passwords, or 'pws' to read the .age file."
      }
    '';
  };

  # Unofficial Bitwarden CLI (keeps vault unlocked via rbw-agent, like ssh-agent).
  programs.rbw.enable = true;

  # Cross-shell prompt, gruvbox-themed.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      palette = "gruvbox_dark";
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      palettes.gruvbox_dark = {
        fg = "#ebdbb2";
        blue = "#83a598";
        green = "#b8bb26";
        yellow = "#fabd2f";
        red = "#fb4934";
        purple = "#d3869b";
        aqua = "#8ec07c";
        orange = "#fe8019";
      };
      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
      git_branch = {
        symbol = " ";
        style = "bold purple";
      };
      git_status.style = "bold yellow";
      nix_shell = {
        symbol = " ";
        style = "bold aqua";
        format = "via [$symbol$name]($style) ";
      };
      cmd_duration = {
        min_time = 500;
        style = "bold yellow";
      };
    };
  };

  programs.zoxide.enable = true; # smarter `cd` (z), integrates with fzf
  programs.fzf.enable = true; # fuzzy finder + Ctrl-R / Ctrl-T bindings

  programs.codex = {
    enable = true;
  };
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
    gitCredentialHelper.enable = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  # PDF viewer configuration
  programs.zathura = {
    enable = true;
    extraConfig = "set selection-clipboard clipboard";
    options = {
      # UI Colors
      notification-bg = "#282a2e";
      notification-fg = "#c5c8c6";
      completion-bg = "#282a2e";
      completion-fg = "#c5c8c6";

      # PDF Recolor (Dark Mode)
      recolor = "true";
      recolor-lightcolor = "#000000"; # Page background
      recolor-darkcolor = "#c5c8c6"; # Text color

      # General
      default-bg = "#1d1f21";
      statusbar-fg = "#c5c8c6";
    };
  };

  # Python plotting library configuration
  programs.thunderbird = {
    enable = true;
    settings = {
      # Example: turn off the welcome page
      "browser.startup.homepage" = "about:blank";
      # example: enable GPG integration
      "mail.openpgp.enable" = true;
    };
    # If you want multiple profiles, you can define them here:
    profiles = {
      default = {
        isDefault = true;
      };
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Serrial Error";
        email = "serrialerror@outlook.com";
      };
    };
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = false;
      };
    };
  };

  # Rofi configuration
  programs.rofi = {
    enable = true;
    theme = "gruvbox-dark";
    configPath = ".config/rofi/config.rasi";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      icon-theme = "Papirus";
      font = "Fira Code 12";
      width = 50;
      lines = 10;
      padding = 20;
      bw = 2;
      separator-style = "none";
      hide-scrollbar = true;
      fullscreen = false;
      location = 0;
      fixed-num-lines = true;
      terminal = "alacritty";
    };
  };
  programs.nvf = {
    enable = true;
    settings = {
      vim = {

        # luaConfigRC.codecompanion = ''
        # -- Keybindings
        # vim.keymap.set("n", "<leader>cc", "<cmd>CodeCompanionChat<cr>", { desc = "Open AI chat" })
        # vim.keymap.set("v", "<leader>cc", "<cmd>CodeCompanionChat<cr>", { desc = "Chat with selection" })
        # vim.keymap.set("n", "<leader>ca", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions menu" })
        # '';

        treesitter = {
          grammars = [ ];
        };
        # WORKAROUND for nvf rev 63d8fc82d6: its vim.maps -> vim.keymaps
        # migration shim reads every legacy category unconditionally, and the
        # legacy options have no defaults, so evaluation fails unless ALL of
        # them are defined. Delete this whole block after `nix flake update nvf`.
        maps = {
          normal = { };
          insert = { };
          select = { };
          visual = { };
          terminal = { };
          command = { };
          visualOnly = { };
          operator = { };
          insertCommand = { };
          lang = { };
          normalVisualOp = { };
        };
        theme = {
          enable = true;
          name = "gruvbox";
          style = "dark";
        };
        /*
          luaConfigRC.myIndentation = ''
          				vim.opt.expandtab = false
          				vim.opt.shiftwidth = 4
          				vim.opt.tabstop = 4
          			'';
        */
        clipboard.enable = true;
        clipboard.providers.xclip.enable = true;
        clipboard.registers = "unnamedplus";
        statusline.lualine.enable = true;
        telescope.enable = true;
        autocomplete.nvim-cmp.enable = true;
        languages = {
          enableTreesitter = true;
          nix.enable = true;
          clang.enable = true;
          typescript.enable = true;
          rust.enable = true;
          # Typst with tinymist (nvf's default and only typst LSP server)
          typst.enable = true;
        };
        lsp = {
          enable = true;
          servers = {
            clangd = {
              enable = true;
              # Resolve clangd from PATH instead of nvf's hardcoded store
              # path, so nix dev shells can ship a project-specific clangd
              # (e.g. a cross-compile-aware wrapper for VEX PROS). Outside a
              # dev shell this falls back to the wrapped clang-tools clangd
              # from home.packages, preserving host-project behavior.
              cmd = lib.mkForce [ "clangd" ];
            };
          };
        };
        # Must run after nvf's "lsp-servers" DAG entry, which does an
        # overwriting `vim.lsp.config["tinymist"] = ...` assignment; this
        # vim.lsp.config() call merges our settings on top of it.
        luaConfigRC.tinymist-export = inputs.nvf.lib.nvim.dag.entryAfter [ "lsp-servers" ] ''
          vim.lsp.config("tinymist", {
            settings = {
              exportPdf = "onSave",
              outputPath = "$dir/$name",
              formatterMode = "typstyle",
            },
          })

          -- pin the root document so editing chapters/03.typ still
          -- compiles main.typ rather than the fragment
          vim.keymap.set("n", "<leader>tp", function()
            vim.lsp.buf.execute_command({
              command = "tinymist.pinMain",
              arguments = { vim.api.nvim_buf_get_name(0) },
            })
          end, { desc = "Typst: pin main file" })
        '';
      };
    };
  };
  programs.claude-code = {
    enable = true;
  };
  programs.gemini-cli = {
    enable = true;
  };
  home.packages = [
    pkgs.devenv
    # Fallback clangd for nvim (see vim.lsp.servers.clangd.cmd); dev shells
    # may shadow it with a project-specific wrapper.
    pkgs.clang-tools
    # pinentry for rbw. gtk2 package includes pinentry-gtk-2 (GUI) and
    # pinentry-tty; cannot install pinentry-curses alongside it (same bin paths).
    pkgs.pinentry-gtk2
  ];

  programs.vinegar.enable = true;
  # Create Rofi theme directory and theme file
  home.file.".config/rofi/themes/gruvbox-dark.rasi" = {
    text = ''
      	  * {
      		  bg: #282828;
      		  bg-alt: #3c3836;
      		  fg: #ebdbb2;
      		  fg-alt: #a89984;

      		  border: 0;
      		  margin: 0;
      		  padding: 0;
      		  spacing: 0;
      	  }

      	  window {
                width: 50%;
                background-color: @bg;
            }

            element {
                padding: 8 12;
                background-color: transparent;
            }

            element normal.normal {
                background-color: transparent;
                text-color: @fg;
            }

            element normal.urgent {
                background-color: #fb4934;
                text-color: @bg;
            }

            element normal.active {
                background-color: #458588;
                text-color: @bg;
            }

            element selected.normal {
                background-color: #458588;
                text-color: @bg;
            }

            element selected.urgent {
                background-color: #fb4934;
                text-color: @bg;
            }

            element selected.active {
                background-color: #458588;
                text-color: @bg;
            }

            element-text {
                background-color: transparent;
                text-color: inherit;
                vertical-align: 0.5;
            }

            element-icon {
                background-color: transparent;
                text-color: inherit;
                size: 24;
                padding: 0 10 0 0;
            }

            entry {
                padding: 12;
                background-color: @bg-alt;
            }

            inputbar {
                children: [entry];
            }

            listview {
                background-color: @bg;
                columns: 1;
                lines: 10;
            }

            mainbox {
                children: [inputbar, listview];
            }

            prompt {
                enabled: true;
                padding: 12 0 0 0;
                background-color: @bg-alt;
            }

            textbox-prompt-colon {
                expand: false;
                str: ":";
                margin: 0 0.3em 0 0;
                text-color: @fg-alt;
            }
    '';
  };

  # Run the wallpaper script (the tracked copy in the repo) when X starts.
  xsession.initExtra = ''
    $HOME/git/nixos-config/set-random-wallpaper.sh
  '';

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    XDG_SESSION_TYPE = "x11"; # Ensure X11 clipboard is used
    XDG_DATA_DIRS = "/var/lib/flatpak/exports/share:${config.home.homeDirectory}/.local/share/flatpak/exports/share:$XDG_DATA_DIRS";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager = {
    enable = true;
  };

  services.syncthing = {
    enable = true;
    settings = {
      devices = {
        "laptop" = {
          id = "QSDBXQP-LWMP27Y-2R3UPXB-FJKCFCL-BYFXURB-JAJU4W3-IWZKTTJ-HURJ5QC";
        };
      };
      folders = {
        "Documents" = {
          path = "${config.home.homeDirectory}/Documents";
          devices = [ "laptop" ];
        };
        "Pictures" = {
          path = "${config.home.homeDirectory}/Pictures";
          devices = [ "laptop" ];
        };
        "Videos" = {
          path = "${config.home.homeDirectory}/Videos";
          devices = [ "laptop" ];
        };
        "Music" = {
          path = "${config.home.homeDirectory}/Music";
          devices = [ "laptop" ];
        };
      };
    };
  };
  services.dunst.enable = true;

  # Update the terminal path in i3 config
  xsession.windowManager.i3.config.terminal = "${pkgs.alacritty}/bin/alacritty";
}
