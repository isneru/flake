{
  pkgs,
  config,
  fonts,
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
    iconTheme = {
      name = "rose-pine";
      package = pkgs.rose-pine-icon-theme;
    };
    cursorTheme = {
      name = "BreezeX-RosePine-Linux";
      package = pkgs.rose-pine-cursor;
    };
    font = {
      name = fonts.mono;
      size = 11;
    };
  };

  qt = {
    enable = true;

    platformTheme.name = "qtct";
  };
}
