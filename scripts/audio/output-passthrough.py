import os
import pathlib

rc = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config"))
rc = rc / "easyeffects/db/easyeffectsrc"
rc.parent.mkdir(parents=True, exist_ok=True)
lines = rc.read_text().splitlines() if rc.exists() else []
out, seen, i = [], False, 0
while i < len(lines):
    out.append(lines[i])
    if lines[i].strip() == "[EffectsPipelines]":
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
    out += ["", "[EffectsPipelines]", "processAllOutputs=false"]
rc.write_text("\n".join(out).strip("\n") + "\n")
