{ ... }:
{
  flake.modules.homeManager.spotify =
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
      programs.spicetify = {
        enable = true;
        theme = spicePkgs.themes.sleek;

        customColorScheme = builtins.mapAttrs (_: strip) {
          text = style.colors.fg;
          subtext = style.colors.fgDim;
          main = style.colors.bg;
          main-elevated = style.colors.bgAlt;
          highlight = style.colors.bgAlt;
          highlight-elevated = style.colors.border;
          sidebar = style.colors.bgDim;
          player = style.colors.bg;
          card = style.colors.bgAlt;
          shadow = style.colors.bgDim;
          selected-row = style.colors.border;
          button = style.colors.accent;
          button-active = style.colors.purple;
          button-disabled = style.colors.fgMuted;
          tab-active = style.colors.bgAlt;
          notification = style.colors.info;
          notification-error = style.colors.error;
          equalizer = style.colors.accent;
          misc = style.colors.fgMuted;
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
    };
}
