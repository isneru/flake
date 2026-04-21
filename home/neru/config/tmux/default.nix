{
  pkgs,
  utils,
  colors,
  ...
}:
{
  home.packages = with pkgs; [ tmux ];

  xdg.configFile."tmux/tmux.conf" = {
    source = utils.create_symlink "${utils.dotfiles}/tmux/tmux.conf";
  };

  xdg.configFile."tmux/plugins" = {
    source = utils.create_symlink "${utils.dotfiles}/tmux/plugins";
  };

  xdg.configFile."tmux/bar.conf".text = ''
    set-option -g status-position top
    set -g status-style bg=default,fg=default

    set -g status-left " "
    set -g status-right "#[fg=default]#S "

    set -g window-status-format "●"
    set -g window-status-current-format "●"

    set -g window-status-style "fg=${colors.fgMuted}"
    set -g window-status-current-style "#{?window_zoomed_flag,fg=${colors.orange},fg=${colors.purple}\,nobold}"
    set -g window-status-bell-style "fg=${colors.error},nobold"
  '';
}
