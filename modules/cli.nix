{ ... }:
{
  flake.modules.homeManager.cli =
    { style, ... }:
    {
      programs.btop = {
        enable = true;
        settings = {
          theme_background = true;
          rounded_corners = style.radius > 0;
          terminal_sync = true;
          graph_symbol = "braille";
          presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
          save_config_on_exit = false;
          update_ms = 2000;
          net_auto = true;
          net_sync = true;
          show_battery = true;
          show_battery_watts = true;
          show_cpu_watts = true;
          show_coretemp = true;
          proc_colors = true;
          proc_gradient = true;
          mem_graphs = true;
          show_disks = true;
          show_io_stat = true;
        };
      };

      programs.zsh = {
        enable = true;
        enableCompletion = false;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        shellAliases = {
          # keep-sorted start
          ".." = "cd ..";
          ":Q" = "exit";
          ":q" = "exit";
          cdt = ''cd "$(git rev-parse --show-toplevel)"'';
          lg = "lazygit";
          pdf = "zathura";
          # keep-sorted end
        };
        initContent = ''
          autoload -Uz compinit
          if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then compinit; else compinit -C; fi

          bindkey -v
          export KEYTIMEOUT=1

          zle-keymap-select() {
            if [[ $KEYMAP == vicmd ]]; then echo -ne "\e[1 q"
            else echo -ne "\e[5 q"; fi
          }
          zle -N zle-keymap-select
          echo -ne "\e[5 q"
          preexec() { echo -ne "\e[5 q"; }

          bindkey -M viins "^[[A" up-line-or-search
          bindkey -M viins "^[[B" down-line-or-search
          bindkey -M vicmd "^[[A" up-line-or-search
          bindkey -M vicmd "^[[B" down-line-or-search
          bindkey -M viins "^R" history-incremental-search-backward

          v() {
            if [[ $1 == *:* ]]; then
              nvim "+''${1##*:}" "''${1%%:*}"
            else
              nvim "$@"
            fi
          }
        '';
      };

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };

      programs.zathura = {
        enable = true;
        options = {
          font = "${style.fonts.mono} ${toString style.fonts.sizeUi}";
          selection-notification = true;
          guioptions = "none";
        };
      };
    };
}
