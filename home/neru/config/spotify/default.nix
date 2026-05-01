{
  pkgs,
  inputs,
  style,
  ...
}:

let
  spicePkgs = inputs.spicetify.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  strip = hex: builtins.substring 1 (-1) hex;
in
{
  imports = [ inputs.spicetify.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.sleek;

    customColorScheme = {
      text = strip style.colors.fg;
      subtext = strip style.colors.fgDim;
      main = strip style.colors.bg;
      main-elevated = strip style.colors.bgAlt;
      highlight = strip style.colors.bgAlt;
      highlight-elevated = strip style.colors.border;
      sidebar = strip style.colors.bgDim;
      player = strip style.colors.bg;
      card = strip style.colors.bgAlt;
      shadow = strip style.colors.bgDim;
      selected-row = strip style.colors.border;
      button = strip style.colors.accent;
      button-active = strip style.colors.purple;
      button-disabled = strip style.colors.fgMuted;
      tab-active = strip style.colors.bgAlt;
      notification = strip style.colors.info;
      notification-error = strip style.colors.error;
      equalizer = strip style.colors.accent;
      misc = strip style.colors.fgMuted;
    };

    enabledExtensions = with spicePkgs.extensions; [
      # keep-sorted start
      adblock
      beautifulLyrics
      hidePodcasts
      shuffle
      # keep-sorted end
    ];

    enabledCustomApps = with spicePkgs.apps; [
      # keep-sorted start
      lyricsPlus
      newReleases
      # keep-sorted end
    ];
  };
}
