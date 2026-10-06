{ ... }:
{
  flake.modules.homeManager.mpv =
    { pkgs, style, ... }:
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
          keep-open = "yes";
          osc = "no";
          osd-bar = "no";
          osd-font = style.fonts.mono;
          volume = 50;
          volume-max = 150;
          ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
        };
      };

      theme-engine.apps.mpv = {
        target = "~/.config/mpv/script-opts/uosc.conf";
        template = builtins.readFile ./uosc.conf.tmpl;
      };
    };
}
