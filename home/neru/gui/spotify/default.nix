{ pkgs, inputs, ... }:

let
  spicePkgs = inputs.spicetify.legacyPackages.${pkgs.system};
in
{
  imports = [ inputs.spicetify.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.sleek;

    colorScheme = "RosePine";

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle
      beautifulLyrics
    ];

    enabledCustomApps = with spicePkgs.apps; [
      newReleases
      lyricsPlus
    ];
  };
}
