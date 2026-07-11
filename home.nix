{config, inputs, pkgs, lib, ... }:

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
    settings.experimental-features = [ "nix-command" "flakes" ];
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
  
  programs.fish = {
    enable = true;
    shellAbbrs = {
      nrs = "sudo nixos-rebuild switch --flake /home/connor/git/nixos-config#default --impure";
    };
  };
  programs.codex = {
    enable = true;
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
			recolor-darkcolor = "#c5c8c6";  # Text color

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
			default = { isDefault = true; };
		};
	};

	# Git configuration
	programs.git = {
		enable = true;
		settings = {
			user = {
				name  = "Serrial Error";
				email = "serrialerror@outlook.com";
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
				grammars = [];
			};
			# WORKAROUND for nvf rev 63d8fc82d6: its vim.maps -> vim.keymaps
			# migration shim reads every legacy category unconditionally, and the
			# legacy options have no defaults, so evaluation fails unless ALL of
			# them are defined. Delete this whole block after `nix flake update nvf`.
			maps = {
				normal = {};
				insert = {};
				select = {};
				visual = {};
				terminal = {};
				command = {};
				visualOnly = {};
				operator = {};
				insertCommand = {};
				lang = {};
				normalVisualOp = {};
			};
			theme = { enable = true; name = "gruvbox"; style = "dark"; };
			/* luaConfigRC.myIndentation = ''
				vim.opt.expandtab = false
				vim.opt.shiftwidth = 4
				vim.opt.tabstop = 4
			''; */
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
			};
			lsp = {
				enable = true;
				servers = {
					clangd = {
						enable = true;
					};
				};
			};
		};
	};
};
	programs.claude-code = {
		enable = true;	
	};
programs.aichat = {
  enable = true;
  
  settings = {
    model = "ollama:qwen2.5-coder:14b";
    rag_embedding_model = "nomic-embed-text:latest";
    rag_top_k = 5;
    temperature = 0.5;
    stream = true;
    save = true;
    highlight = true;
    
    clients = [
      {
        # Order matters! type and name must come first
        type = "openai-compatible";
        name = "ollama";
        api_base = "http://localhost:11434/v1";
        models = [
          {
            name = "qwen2.5-coder:14b";
            max_input_tokens = 131072;
            supports_function_calling = true;
          }
          {
            name = "qwen2.5-coder:7b";
            max_input_tokens = 131072;
            supports_function_calling = true;
          }
          {
            name = "nomic-embed-text:latest";
            type = "embedding";
            default_chunk_size = 1000;
            max_batch_size = 50;
          }
        ];
      }
    ];
  };
  
  agents = {
    review = {
      model = "ollama:qwen2.5-coder:14b";
      temperature = 0.3;
      instructions = "You are a code reviewer. Analyze code for bugs, performance issues, and best practices.";
    };
    coder = {
      model = "ollama:qwen2.5-coder:14b";
      temperature = 0.3;
      use_tools = "fs";
      instructions = "You are a coding assistant. Provide concise, practical solutions. Make sure to be detailed in your work.";
    };
    chat = {
      model = "ollama:qwen2.5-coder:7b";
      temperature = 0.7;
      instructions = "You are a chatbot, a variety of questions will be asked. Be as detailed and thoughtful as possible in your answer. Listen to everything the user has to say, it is your friend.";
    };
  };
};
	programs.gemini-cli = {
		enable = true;
	};
	home.packages = [ pkgs.devenv ];

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

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    XDG_SESSION_TYPE = "x11";  # Ensure X11 clipboard is used
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
        "laptop" = { id = "QSDBXQP-LWMP27Y-2R3UPXB-FJKCFCL-BYFXURB-JAJU4W3-IWZKTTJ-HURJ5QC"; };
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
  # Create Rofi launcher script
  home.file.".local/bin/rofi-launcher.sh" = {
    text = ''
      #!/usr/bin/env bash
      export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:$XDG_DATA_DIRS"
      rofi -modi drun -show drun -dump-xresources
    '';
    executable = true;
  };

  # Update the terminal path in i3 config
  xsession.windowManager.i3.config.terminal = "${pkgs.alacritty}/bin/alacritty";
}

