{ ... }:
{
  flake.modules.homeManager.packages =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # keep-sorted start
        curl
        eza
        fzf
        git
        just
        lazygit
        libnotify
        python3
        wl-clipboard
        # keep-sorted end
      ];
    };
}
