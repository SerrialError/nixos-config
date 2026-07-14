{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.nvf.homeManagerModules.default
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
  home.file."bin/element" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      eval $(gnome-keyring-daemon --start --components=secrets)
      export GNOME_KEYRING_CONTROL
      export DBUS_SESSION_BUS_ADDRESS
      ${pkgs.element-desktop}/bin/element-desktop "$@"
    '';
  };

  # X session configuration
  xsession.enable = true;
  # home-manager's default import list omits PATH. DBus-activatable apps
  # launched from rofi (GDesktopAppInfo) inherit the systemd --user
  # environment, which otherwise only has systemd's own bindir — so
  # Impression can't find `tar` and shows a false "No Connection" screen.
  # (CLI launches inherit the shell PATH and work.)
  xsession.importedVariables = [ "PATH" ];

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

    # Declarative default apps. home-manager takes over ~/.config/mimeapps.list
    # (the old mutable copy is saved as mimeapps.list.backup). Images previously
    # resolved to chromium because its desktop file registers image types;
    # pin them to qimgv here so thunar/lf/xdg-open all agree.
    mimeApps =
      let
        images = builtins.listToAttrs (
          map
            (t: {
              name = t;
              value = "qimgv.desktop";
            })
            [
              "image/jpeg"
              "image/png"
              "image/gif"
              "image/bmp"
              "image/webp"
              "image/tiff"
            ]
        );
        browser = builtins.listToAttrs (
          map
            (t: {
              name = t;
              value = "floorp.desktop";
            })
            [
              "text/html"
              "application/xhtml+xml"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
            ]
        );
      in
      {
        enable = true;
        defaultApplications =
          images
          // browser
          // {
            "application/pdf" = "org.pwmt.zathura.desktop";
            "video/webm" = "mpv.desktop";
            "video/mp4" = "mpv.desktop";
            "video/x-matroska" = "mpv.desktop";
            "x-scheme-handler/mailto" = "thunderbird.desktop";
            "message/rfc822" = "thunderbird.desktop";
          };
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
      nrb = "sudo nixos-rebuild build --flake /home/connor/git/nixos-config#default --impure |& nom";
      # server: build locally / deploy over SSH. sudo is needed because the
      # eval reads the root-only agenix keyfile (--impure); --preserve-env
      # keeps connor's ssh-agent usable for the remote hop. Replace
      # SERVER-IP-PLACEHOLDER with the server's LAN address.
      srb = "sudo nixos-rebuild build --flake /home/connor/git/nixos-config#server --impure |& nom";
      srs = "sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild switch --flake /home/connor/git/nixos-config#server --impure --target-host connor@SERVER-IP-PLACEHOLDER --sudo --ask-sudo-password";
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
      # System info splash on every new interactive shell
      fastfetch

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

      # caligula ships no zsh completion and has no `completions` generator
      # subcommand, so its subcommands/flags don't tab-complete out of the box.
      # Hand-rolled from `caligula --help` / `caligula burn --help`.
      _caligula() {
        local curcontext="$curcontext" state line
        _arguments -C \
          '(-h --help)'{-h,--help}'[Print help]' \
          '(-V --version)'{-V,--version}'[Print version]' \
          '1: :->cmd' \
          '*:: :->args'
        case $state in
          cmd)
            _values 'caligula command' \
              'burn[Burn an image to a disk]' \
              'help[Print help for a subcommand]'
            ;;
          args)
            case $line[1] in
              burn)
                _arguments \
                  '-o[Where to write the output]:output:_files' \
                  '(-z --compression)'{-z,--compression}'[Input compression format]:format:(ask auto none gz bz2 xz lz4 zst)' \
                  '(-s --hash)'{-s,--hash}'[Hash of the input file]:hash:' \
                  '--hash-file[Where to look for the hash]:file:_files' \
                  '--hash-of[Is the hash of the raw or compressed file]:kind:(raw compressed)' \
                  '--show-all-disks[Show all disks, removable or not]' \
                  '--interactive[Run in interactive mode or not]:mode:(auto always never)' \
                  '(-f --force)'{-f,--force}'[Do not confirm before destroying the disk]' \
                  '--root[Try to become root for the output file]:policy:(ask always never)' \
                  '(-h --help)'{-h,--help}'[Print help]' \
                  '(-V --version)'{-V,--version}'[Print version]' \
                  '1:image:_files'
                ;;
            esac
            ;;
        esac
      }
      compdef _caligula caligula
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

  # Email client configuration
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
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
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
        # nvf's vim.maps -> vim.keymaps migration shim is buggy: its
        # `config.vim.keymaps = mkMerge [ (pipe cfg.maps ...) ]` maps over all
        # vim.maps.* sub-options, which upstream declares WITHOUT a default.
        # The module system must WHNF that definition just to resolve option
        # priority, so it forces every category and eval fails unless ALL are
        # defined here. Defining them is what emits the "vim.maps.* deprecated"
        # warnings on rebuild -- those are cosmetic and unavoidable until nvf
        # gives vim.maps.* a `{}` default (no mkForce/keymaps override helps,
        # the read happens during priority discharge). Latest nvf as of
        # 2026-07-12 still has this. Revisit after a future nvf update.
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
        # 4-space indentation (nvf/neovim default tabstop is 8).
        options = {
          expandtab = true;
          tabstop = 4;
          shiftwidth = 4;
          softtabstop = 4;
        };

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
        # Settings are applied via workspace/didChangeConfiguration after
        # server init (nvf enables the server in the same section).
        luaConfigRC.tinymist-export = inputs.nvf.lib.nvim.dag.entryAfter [ "lsp-servers" ] ''
          vim.lsp.config("tinymist", {
            settings = {
              exportPdf = "onSave",
              -- Must include $root. `$dir/$name` alone is relative and, when
              -- $dir is empty (file at project root), becomes `/name.pdf` →
              -- EACCES. See tinymist PathPattern docs and issue #2400.
              -- Empty outputPath also works (special-cased next-to-source).
              outputPath = "$root/$dir/$name",
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
    $HOME/git/nixos-config/scripts/set-random-wallpaper.sh
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
