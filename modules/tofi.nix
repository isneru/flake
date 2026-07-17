{ ... }:
{
  flake.modules.homeManager.tofi = {
    programs.tofi.enable = true;

    # Stateless: tofi re-reads its config on every spawn, no reload needed.
    theme-engine.apps.tofi.target = "~/.config/tofi/config";
    theme-engine.apps.tofi.template = ''
      width=100%
      height=100%
      border-width=0
      outline-width=0

      padding-left=35%
      padding-top=35%
      result-spacing=25
      num-results=5

      font={{mono}}
      font-size={{sizeLarge}}

      background-color={{bgOverlay}}
      text-color={{fg}}

      selection-color={{accent}}
      selection-background={{bg}}
      selection-background-padding=5, 10
      selection-background-corner-radius={{radius}}

      prompt-color={{accent}}
    '';
  };
}
