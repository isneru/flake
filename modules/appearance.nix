{ ... }:
{
  flake.modules.homeManager.appearance =
    { pkgs, ... }:
    {
      home.pointerCursor = {
        enable = true;
        name = "BreezeX-RosePine-Linux";
        package = pkgs.rose-pine-cursor;
        size = 24;
        dotIcons.enable = false;
        gtk.enable = true;
        x11.enable = true;
      };

      home.packages = with pkgs; [
        # keep-sorted start
        nerd-fonts.caskaydia-cove
        nerd-fonts.fira-code
        nerd-fonts.geist-mono
        nerd-fonts.go-mono
        nerd-fonts.iosevka-term
        nerd-fonts.jetbrains-mono
        # keep-sorted end
      ];

      catppuccin = {
        enable = true;
        # Explicit opt-in per app instead of autoEnable: the theme engine owns
        # most apps' colors, and autoEnable silently grabbing any app it
        # recognizes caused repeated two-owners fights (nvim, kitty, vesktop,
        # swaync, ...) that each needed an explicit disable.
        autoEnable = false;
        flavor = "mocha";
        accent = "mauve";
        # keep-sorted start
        btop.enable = true;
        starship.enable = true;
        thunderbird.enable = true;
        tmux.enable = true;
        zathura.enable = true;
        zsh-syntax-highlighting.enable = true;
        # keep-sorted end
      };
    };
}
