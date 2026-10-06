{ ... }:
{
  flake.modules.homeManager.music =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      musicDir = "${config.home.homeDirectory}/music";
      themeFile = "${config.xdg.configHome}/rmpc/themes/theme-engine.ron";
      cavaFifo = "${config.xdg.cacheHome}/mpd-cava.fifo";
    in
    {
      home.packages = [
        pkgs.cava
        pkgs.rmpc
        (pkgs.writeShellApplication {
          name = "sync-playlist";
          runtimeInputs = with pkgs; [
            # keep-sorted start
            ffmpeg
            xdg-utils
            yt-dlp
            # keep-sorted end
          ];
          text = ''
            : "''${MUSIC_DIR:=${musicDir}}"
          ''
          + builtins.readFile ./sync-playlist.sh;
        })
      ];

      services.mpd = {
        enable = true;
        musicDirectory = musicDir;
        network.startWhenNeeded = true;
        extraConfig = ''
          auto_update "yes"
          restore_paused "yes"

          audio_output {
            type "pipewire"
            name "PipeWire"
          }

          audio_output {
            type "fifo"
            name "cava"
            path "${cavaFifo}"
            format "44100:16:2"
          }
        '';
      };

      home.activation.mpdMusicDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg musicDir}
      '';

      services.mpd-mpris.enable = true;

      services.mpd-discord-rpc = {
        enable = true;
        settings = {
          hosts = [ "127.0.0.1:6600" ];
          format = {
            details = "$title";
            state = "by $artist";
            small_image = "";
            display_type = "details";
          };
        };
      };

      xdg.configFile."rmpc/config.ron".text = ''
        #![enable(implicit_some)]
        #![enable(unwrap_newtypes)]
        #![enable(unwrap_variant_newtypes)]
        (
            address: "127.0.0.1:6600",
            theme: "theme-engine",
            volume_step: 5,
            scrolloff: 4,
            wrap_navigation: true,
            select_current_song_on_change: true,
            cava: (
                input: (method: Fifo, source: "${cavaFifo}"),
            ),
        ${builtins.readFile ./tabs.ron}
        )
      '';

      theme-engine.apps.rmpc = {
        target = themeFile;
        reload = [
          "rmpc"
          "remote"
          "set"
          "theme"
          themeFile
        ];
        template = ''
              #![enable(implicit_some)]
              #![enable(unwrap_newtypes)]
              #![enable(unwrap_variant_newtypes)]
              (
                  default_album_art_path: None,
                  text_color: "{{fg}}",
                  modal_background_color: "{{bgDim}}",
                  modal_backdrop: true,
                  borders_style: (fg: "{{border}}"),
                  highlight_border_style: (fg: "{{accent}}"),
                  highlighted_item_style: (fg: "{{accent}}", modifiers: "Bold"),
                  current_item_style: (fg: "{{bg}}", bg: "{{accent}}", modifiers: "Bold"),
                  preview_label_style: (fg: "{{fgDim}}"),
                  preview_metadata_group_style: (fg: "{{accent}}", modifiers: "Bold"),
                  symbols: (
                      song: "󰎇 ",
                      dir: "󰉋 ",
                      playlist: "󰲹 ",
                      marker: "󰄲 ",
                      ellipsis: "…",
                      song_style: (fg: "{{fgDim}}"),
                      dir_style: (fg: "{{blue}}"),
                      playlist_style: (fg: "{{cyan}}"),
                  ),
                  level_styles: (
                      info: (fg: "{{info}}", bg: "{{bgDim}}"),
                      warn: (fg: "{{warning}}", bg: "{{bgDim}}"),
                      error: (fg: "{{error}}", bg: "{{bgDim}}"),
                      debug: (fg: "{{success}}", bg: "{{bgDim}}"),
                      trace: (fg: "{{fgMuted}}", bg: "{{bgDim}}"),
                  ),
                  progress_bar: (
                      symbols: ["|", "▓", "█", "░", "|"],
                      track_style: (fg: "{{bgAlt}}"),
                      elapsed_style: (fg: "{{accent}}"),
                      thumb_style: (fg: "{{accent}}"),
                      use_track_when_empty: true,
                  ),
                  scrollbar: (
                      symbols: ["│", "█", " ", " "],
                      track_style: (fg: "{{bgAlt}}"),
                      ends_style: (fg: "{{border}}"),
                      thumb_style: (fg: "{{accent}}"),
                  ),
                  tab_bar: (
                      active_style: (fg: "{{bg}}", bg: "{{accent}}", modifiers: "Bold"),
                      inactive_style: (fg: "{{fgMuted}}"),
                  ),
                  lyrics: (
                      timestamp: false,
                  ),
                  cava: (
                      bar_color: Gradient({0: "{{border}}", 50: "{{blue}}", 100: "{{accent}}"}),
                      bar_width: 2,
                      bar_spacing: 1,
                  ),
          ${builtins.readFile ./components.ron}
              )
        '';
      };
    };
}
