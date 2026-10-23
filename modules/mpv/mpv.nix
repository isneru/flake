{ ... }:
{
  flake.modules.homeManager.mpv =
    { pkgs, ... }:
    {
      programs.mpv = {
        enable = true;

        scripts = with pkgs.mpvScripts; [
          # keep-sorted start
          sponsorblock-minimal
          thumbfast
          uosc
          # keep-sorted end
        ];

        config = {
          autofit-larger = "90%x90%";
          border = "no";
          include = "~~/font.conf";
          keep-open = "yes";
          osc = "no";
          osd-bar = "no";
          volume = 50;
          volume-max = 150;
          wayland-internal-vsync = "yes";
          ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
        };
      };

      theme-engine.apps.mpv-font = {
        target = "~/.config/mpv/font.conf";
        template = ''
          osd-font={{mono}}
        '';
      };

      theme-engine.apps.mpv = {
        target = "~/.config/mpv/script-opts/uosc.conf";
        template = builtins.readFile ./uosc.conf.tmpl;
      };
    };
}
