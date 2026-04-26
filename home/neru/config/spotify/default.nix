{ pkgs, inputs, colors, ... }:

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
      text = strip colors.fg;
      subtext = strip colors.fgDim;
      main = strip colors.bg;
      main-elevated = strip colors.bgAlt;
      highlight = strip colors.bgAlt;
      highlight-elevated = strip colors.border;
      sidebar = strip colors.bgDim;
      player = strip colors.bg;
      card = strip colors.bgAlt;
      shadow = strip colors.bgDim;
      selected-row = strip colors.border;
      button = strip colors.accent;
      button-active = strip colors.purple;
      button-disabled = strip colors.fgMuted;
      tab-active = strip colors.bgAlt;
      notification = strip colors.info;
      notification-error = strip colors.error;
      equalizer = strip colors.accent;
      misc = strip colors.fgMuted;
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
