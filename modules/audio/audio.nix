{ ... }:
{
  flake.modules.nixos.audio = {
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.extraConfig."51-easyeffects-source"."monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_input.*"; } ];
          actions.update-props."priority.session" = -1;
        }
      ];
    };
  };

  flake.modules.homeManager.audio =
    { pkgs, ... }:
    {
      services.easyeffects.enable = true;

      systemd.user.services.easyeffects.Service.ExecStartPre = toString (
        pkgs.writeShellScript "easyeffects-output-passthrough" ''
          exec ${pkgs.python3}/bin/python3 - <<'PY'
          import os, pathlib
          rc = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config"))
          rc = rc / "easyeffects/db/easyeffectsrc"
          rc.parent.mkdir(parents=True, exist_ok=True)
          lines = rc.read_text().splitlines() if rc.exists() else []
          out, seen, i = [], False, 0
          while i < len(lines):
              out.append(lines[i])
              if lines[i].strip() == "[Main]":
                  seen = True
                  i += 1
                  out.append("processAllOutputs=false")
                  while i < len(lines) and not lines[i].startswith("["):
                      if not lines[i].startswith("processAllOutputs="):
                          out.append(lines[i])
                      i += 1
                  continue
              i += 1
          if not seen:
              out += ["", "[Main]", "processAllOutputs=false"]
          rc.write_text("\n".join(out).strip("\n") + "\n")
          PY
        ''
      );
    };
}
