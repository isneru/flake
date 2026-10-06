{ ... }:
{
  flake.modules.nixos.files = {
    services.udisks2.enable = true;
  };

  flake.modules.homeManager.files =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        setSessionVariables = true;
        desktop = null;
        projects = null;
        publicShare = null;
        templates = null;
        documents = "${config.home.homeDirectory}/documents";
        download = "${config.home.homeDirectory}/downloads";
        music = "${config.home.homeDirectory}/music";
        pictures = "${config.home.homeDirectory}/pictures";
        videos = "${config.home.homeDirectory}/videos";
      };

      home.packages = [
        (pkgs.writeShellApplication {
          name = "imgview";
          runtimeInputs = with pkgs; [
            ffmpeg
            jq
            swayimg
          ];
          text = builtins.readFile ./imgview.sh;
        })
      ]
      ++ (with pkgs; [
        # keep-sorted start
        xarchiver
        # keep-sorted end
      ]);

      programs.yazi = {
        enable = true;
        shellWrapperName = "y";
        initLua = ./yazi-init.lua;
      };

      xdg.configFile."yazi/theme.toml".source =
        pkgs.runCommand "yazi-theme.toml" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 ${./yazi-theme.py} \
              ${pkgs.yazi-unwrapped.srcs.code_src}/yazi-config/preset/theme-dark.toml > $out
          '';

      xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
        [filechooser]
        cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
        default_dir=$HOME
        env=TERMCMD=kitty --class filepicker
        env=YAZI_BAR=1
        open_mode=suggested
        save_mode=suggested
      '';

      xdg.desktopEntries.yazi-kitty = {
        name = "Yazi";
        exec = "env YAZI_BAR=1 kitty --class yazi yazi %u";
        icon = "yazi";
        terminal = false;
        noDisplay = true;
        mimeType = [ "inode/directory" ];
      };

      xdg.configFile."swayimg/init.lua".text = ''
        swayimg.text.visible = false
      '';

      xdg.desktopEntries.imgview = {
        name = "Image Viewer";
        genericName = "Image Viewer";
        exec = "imgview %F";
        icon = "swayimg";
        terminal = false;
        categories = [
          "Graphics"
          "Viewer"
        ];
        mimeType = [
          "image/avif"
          "image/bmp"
          "image/gif"
          "image/heif"
          "image/jpeg"
          "image/jxl"
          "image/png"
          "image/svg+xml"
          "image/tiff"
          "image/webp"
        ];
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          lib.genAttrs [
            "image/avif"
            "image/bmp"
            "image/gif"
            "image/heif"
            "image/jpeg"
            "image/jpg"
            "image/jxl"
            "image/pjpeg"
            "image/png"
            "image/qoi"
            "image/svg+xml"
            "image/tiff"
            "image/tiff-fx"
            "image/webp"
            "image/x-bmp"
            "image/x-farbfeld"
            "image/x-png"
          ] (_: "imgview.desktop")
          // lib.genAttrs [
            "video/3gpp"
            "video/mp4"
            "video/mpeg"
            "video/ogg"
            "video/quicktime"
            "video/webm"
            "video/x-flv"
            "video/x-matroska"
            "video/x-ms-wmv"
            "video/x-msvideo"
          ] (_: "mpv.desktop")
          // lib.genAttrs [
            "application/xhtml+xml"
            "text/html"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] (_: "org.qutebrowser.qutebrowser.desktop")
          // lib.genAttrs [
            "application/gzip"
            "application/vnd.rar"
            "application/x-7z-compressed"
            "application/x-archive"
            "application/x-bzip"
            "application/x-bzip2"
            "application/x-bzip2-compressed-tar"
            "application/x-compressed-tar"
            "application/x-cpio"
            "application/x-lz4"
            "application/x-lzma"
            "application/x-lzma-compressed-tar"
            "application/x-rar"
            "application/x-tar"
            "application/x-xz"
            "application/x-xz-compressed-tar"
            "application/x-zstd-compressed-tar"
            "application/zip"
            "application/zstd"
          ] (_: "xarchiver.desktop")
          // {
            "inode/directory" = "yazi-kitty.desktop";
            "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
            "x-scheme-handler/discord" = "vesktop.desktop";
          };
      };
    };
}
