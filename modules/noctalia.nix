{ ... }:
{
  flake.modules.homeManager.noctalia = {
    programs.noctalia.enable = true;
    # settings deliberately left empty (Nix's default) - config.toml is fully
    # runtime-template-owned below instead (theme-engine.apps.noctalia-config),
    # same as every other themed app in this repo. Home Manager only manages
    # this xdg.configFile at all when settings != {}; leaving it empty means
    # Nix never touches ~/.config/noctalia/config.toml, so there's no "two
    # owners of one path" conflict with theme-set's own writes to it.

    # Colors stay theme-engine-owned (not Noctalia's own Material-You-style
    # generator) - the palette file is just another {{token}} template, same
    # pattern as every other app registered here.
    #
    # mTertiary uses {{info}}, not {{cyan}} - info is a distinct semantic
    # token that's always identical to cyan across every themes/*.toml file
    # (by design, confirmed by diffing all six), but Noctalia's tertiary role
    # drives informational UI (net throughput, GPU temp in system_tab.cpp),
    # not the terminal. cyan stays reserved for terminal ANSI cyan below, so
    # each token now has exactly one job instead of one color doing both.
    theme-engine.apps.noctalia = {
      target = "~/.config/noctalia/palettes/noctalia-live.json";
      template = builtins.readFile ./noctalia/noctalia-palette.json.tmpl;
      reload = [
        "noctalia"
        "msg"
        "color-scheme-set"
        "custom"
        "noctalia-live"
      ];
    };

    # bar/dock/wallpaper/widget settings, moved here from a Nix-declared
    # programs.noctalia.settings block so bar.main.radius can track the live
    # theme's {{radius}} instead of a build-time seed. Everything else in
    # here is a straight port of what was declared in Nix before - same
    # values, just TOML text now instead of an attrset.
    theme-engine.apps.noctalia-config = {
      target = "~/.config/noctalia/config.toml";
      template = builtins.readFile ./noctalia/config.toml.tmpl;
      reload = [
        "noctalia"
        "msg"
        "config-reload"
      ];
    };
  };
}
