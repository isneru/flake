{ ... }:
{
  flake.modules.homeManager.appearance =
    { pkgs, ... }:
    {
      home.pointerCursor = {
        enable = true;
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
        size = 20;
        dotIcons.enable = false;
        gtk.enable = true;
        x11.enable = true;
      };

      home.packages = with pkgs; [
        # keep-sorted start
        nerd-fonts.blex-mono
        nerd-fonts.caskaydia-cove
        nerd-fonts.commit-mono
        nerd-fonts.fira-code
        nerd-fonts.geist-mono
        nerd-fonts.go-mono
        nerd-fonts.googlesanscode
        nerd-fonts.iosevka-term
        nerd-fonts.jetbrains-mono
        nerd-fonts.martian-mono
        nerd-fonts.monaspace
        nerd-fonts.victor-mono
        # keep-sorted end
      ];
    };
}
