#!/usr/bin/env python3
"""Render every theme against every template, failing on any unreplaced
{{token}}. Run by the flake check (parts/checks.nix) with XDG_CONFIG_HOME
pointing at a synthetic dir holding theme-engine/{themes,templates,
apps.json} - a broken theme or template fails `just check` before it can
ever be applied live."""

import sys

import theme_engine as te


def main() -> None:
    themes = te.list_themes()
    if not themes:
        sys.exit(f"check_render: no themes found in {te.THEMES_DIR}")
    apps = te.load_apps()
    sources = [(f"{name}.tmpl", te.TEMPLATES_DIR / f"{name}.tmpl") for name in apps]
    failures = []
    for theme in themes:
        tokens = te.load_theme(theme)
        for label, path in sources:
            if not path.is_file():
                failures.append(f"{theme}: {label}: file missing")
                continue
            leftover = te.leftover_tokens(te.render(path.read_text(), tokens))
            if leftover:
                failures.append(f"{theme}: {label}: unreplaced tokens: {', '.join(leftover)}")
    if failures:
        sys.exit("\n".join(failures))
    print(f"OK: {len(themes)} themes x {len(sources)} templates rendered clean")


if __name__ == "__main__":
    main()
