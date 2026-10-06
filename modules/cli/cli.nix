{ ... }:
{
  flake.previews.btop.aspects = [ "cli" ];
  flake.previews.btop.build =
    {
      pkgs,
      hm,
      mkApp,
      ...
    }:
    mkApp {
      name = "btop";
      text = ''
        exec ${pkgs.btop}/bin/btop \
          --config ${hm.xdg.configFile."btop/btop.conf".source} \
          "$@"
      '';
    };

  flake.previews.shell.aspects = [
    "cli"
    "starship"
  ];
  flake.previews.shell.build =
    {
      pkgs,
      hm,
      mkApp,
      ...
    }:
    let
      zdotdir = pkgs.runCommand "preview-zdotdir" { } ''
        mkdir -p $out
        cp ${hm.home.file."./.zshrc".source} $out/.zshrc
        cp ${hm.home.file."./.zshenv".source} $out/.zshenv
      '';
    in
    mkApp {
      name = "shell";
      runtimeInputs = with pkgs; [
        # keep-sorted start
        bat
        bat-extras.batman
        eza
        fzf
        lazygit
        starship
        zoxide
        # keep-sorted end
      ];
      text = ''
        export ZDOTDIR=${zdotdir}
        export BAT_CONFIG_PATH=${hm.xdg.configFile."bat/config".source}
        export STARSHIP_CONFIG=${hm.home.file."${hm.xdg.configHome}/starship.toml".source}
        exec ${pkgs.zsh}/bin/zsh "$@"
      '';
    };

  flake.modules.nixos.cli = {
    programs.zsh.enable = true;

    environment.localBinInPath = true;
  };

  flake.modules.homeManager.cli =
    {
      pkgs,
      ...
    }:
    {
      programs.bat = {
        enable = true;
        config.theme = "ansi";
        extraPackages = with pkgs.bat-extras; [
          # keep-sorted start
          batdiff
          batgrep
          batman
          batpipe
          batwatch
          prettybat
          # keep-sorted end
        ];
      };

      programs.btop = {
        enable = true;
        settings = {
          color_theme = "TTY";
          theme_background = false;
          rounded_corners = true;
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
          cat = "bat -p";
          cdt = ''cd "$(git rev-parse --show-toplevel)"'';
          la = "eza -la --icons=always --group-directories-first --git";
          lg = "lazygit";
          ll = "eza -l --icons=always --group-directories-first --git";
          ls = "eza --icons=always --group-directories-first";
          man = "batman";
          pdf = "zathura";
          # keep-sorted end
        };
        initContent = ''
          autoload -Uz compinit
          if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then compinit; else compinit -C; fi

          bindkey -e

          echo -ne "\e[5 q"
          preexec() { echo -ne "\e[5 q"; }

          bindkey "^[[A" up-line-or-search
          bindkey "^[[B" down-line-or-search

          df()    { command df    "$@" | bat -p -l conf; }
          free()  { command free  "$@" | bat -p -l conf; }
          ip()    { command ip    "$@" | bat -p -l conf; }
          lsblk() { command lsblk "$@" | bat -p -l conf; }
          lsmod() { command lsmod "$@" | bat -p -l conf; }
          lscpu() { command lscpu "$@" | bat -p -l cpuinfo; }
          mount() { command mount "$@" | bat -p -l conf; }
          ps()    { command ps    "$@" | bat -p -l conf; }
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
    };
}
