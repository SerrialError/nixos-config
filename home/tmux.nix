{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    escapeTime = 0;
    terminal = "screen-256color";
    historyLimit = 50000;
    keyMode = "vi";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
    extraConfig = ''
      # Enable mouse mode
      set -g mouse on

      # Increase scrollback buffer size
      set -g history-limit 50000

      # Start windows and panes at 1, not 0
      set -g base-index 1
      setw -g pane-base-index 1

      # Automatically set window title
      setw -g automatic-rename on
      set -g set-titles on
      set -g set-titles-string "#T"

      # Status bar customization
      set -g status-style bg=default
      set -g status-left-length 50
      set -g status-right-length 50
      set -g status-left "#[fg=green]#H #[fg=black]• #[fg=green]#(uname -r | cut -c 1-6)#[default]"
      set -g status-right "#[fg=black]• #[fg=green]%H:%M #[fg=black]• #[fg=green]%d-%b-%Y#[default]"

      # Pane border colors
      set -g pane-border-style fg=colour240
      set -g pane-active-border-style fg=colour4

      # Window status colors
      setw -g window-status-style fg=colour240
      setw -g window-status-current-style fg=colour4

      # Message text
      set -g message-style bg=colour235,fg=colour166

      # Pane number display
      set -g display-panes-active-colour colour4
      set -g display-panes-colour colour240

      # Clock
      setw -g clock-mode-colour colour4

      # Enable focus events
      set -g focus-events on

      # Increase tmux messages display time
      set -g display-time 4000

      # Enable true colors
      set -ga terminal-overrides ",*256col*:Tc"

      # Easier window splitting
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Easier window navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Synchronize panes
      bind y set-window-option synchronize-panes\; display-message "synchronize-panes is now #{?pane_synchronized,on,off}"

      # Clear history
      bind C-l send-keys C-l \; clear-history

      # Reload tmux config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
    '';
  };
} 