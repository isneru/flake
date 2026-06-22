{
  pkgs,
  config,
  style,
  ...
}:
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

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.packages = with pkgs; [
    # keep-sorted start
    nerd-fonts.caskaydia-cove
    nerd-fonts.fira-code
    nerd-fonts.geist-mono
    nerd-fonts.iosevka-term
    nerd-fonts.jetbrains-mono
    # keep-sorted end
  ];

  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;
    cursorTheme = {
      name = "BreezeX-RosePine-Linux";
      package = pkgs.rose-pine-cursor;
    };
    font = {
      name = style.fonts.mono;
      size = style.fonts.size;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    accent = "mauve";
    nvim.enable = false;
    tofi.enable = false;
  };
}
