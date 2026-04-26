{ pkgs, colors, ... }:
{
  programs.tmux = {
    enable = true;
    prefix = "'º'";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    terminal = "screen-256color";
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
      set -g repeat-time 1000
      set -g pane-base-index 1
      set-option -g renumber-windows on
      set -g pane-border-lines simple

      unbind '"'
      unbind %
      bind - split-window -v -c "#{pane_current_path}"
      bind | split-window -h -c "#{pane_current_path}"

      bind R source-file ~/.config/tmux/tmux.conf \; display-message "config reloaded"
      bind C-l send-keys C-l \; clear-history

      bind -n C-Tab next-window
      bind -n C-S-Tab previous-window
      bind-key 1 if-shell 'tmux select-window -t :1' "" 'new-window -t :1'
      bind-key 2 if-shell 'tmux select-window -t :2' "" 'new-window -t :2'
      bind-key 3 if-shell 'tmux select-window -t :3' "" 'new-window -t :3'
      bind-key 4 if-shell 'tmux select-window -t :4' "" 'new-window -t :4'
      bind-key 5 if-shell 'tmux select-window -t :5' "" 'new-window -t :5'
      bind-key 6 if-shell 'tmux select-window -t :6' "" 'new-window -t :6'
      bind-key 7 if-shell 'tmux select-window -t :7' "" 'new-window -t :7'
      bind-key 8 if-shell 'tmux select-window -t :8' "" 'new-window -t :8'
      bind-key 9 if-shell 'tmux select-window -t :9' "" 'new-window -t :9'

      set-option -g status-position top
      set -g status-style bg=default,fg=default
      set -g status-left " "
      set -g status-right "#[fg=default]#S "
      set -g window-status-format "#I"
      set -g window-status-current-format "#I"
      set -g window-status-style "fg=${colors.fgMuted}"
      set -g window-status-current-style "#{?window_zoomed_flag,fg=${colors.orange},fg=${colors.purple},nobold}"
      set -g window-status-bell-style "fg=${colors.error},nobold"
    '';
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      {
        plugin = tmux-sessionx;
        extraConfig = ''
          set -g @sessionx-bind 'o'
          set -g @sessionx-window-height '85%'
          set -g @sessionx-window-width '75%'
          set -g @sessionx-zoxide-mode 'on'
        '';
      }
      resurrect
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
    ];
  };
}
