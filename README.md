# flake

NixOS + Home Manager configuration for `victus`, structured as a **dendritic
flake-parts tree**: every `.nix` file under `modules/` is a self-contained,
self-registering module, auto-discovered by `import-tree` - there's no manual
`imports = [ ... ]` list anywhere in `modules/`. A feature that spans both
layers (e.g. Hyprland: compositor enable at the NixOS level, config +
theme registration at the Home Manager level) declares both in one file
instead of being split across a system/user directory boundary.

## Structure

```
flake.nix                    # entry point: inputs + flake-parts + import-tree ./modules
lib/
  style.nix                   # build-time seed palette + fonts (derived from
                               # themes/mocha.toml), threaded as the `style` module arg
hosts/victus/                 # host identity + hardware - not a pooled aspect
  default.nix                  # hostName, networking, users, GPU workarounds
  hardware.nix                  # nixos-generate-config output
modules/
  flake-system.nix             # nixosConfigurations.victus assembly
  flake-checks.nix              # theme-render check (see below)
  flake-formatter.nix            # treefmt (nixfmt, deadnix, stylua, shfmt, keep-sorted)
  flake-apps.nix                  # nix run .#{kitty,tofi,nvim} standalone previews
  boot.nix, locales.nix, desktop.nix,
  secrets.nix, apps.nix                # nixos-only aspects, one file each
  sddm.nix, sddm/                       # SDDM (Xorg-hosted greeter) + hand-packaged
                                          # Samaritan login theme
  hyprland.nix, hyprland/                 # compositor: nixos enable + homeManager
                                            # config (Lua, live-edited via symlink)
  theme-engine.nix, theme-engine/           # runtime theming system - theme-set CLI,
                                              # theme_engine.py, themes/*.toml
  noctalia.nix, noctalia/                     # bar/control-center/launcher shell,
                                                # fully runtime-themed
  cli.nix, packages.nix, appearance.nix,
  scripts.nix, scripts/                         # shell/fonts/cursor/ad-hoc packages,
                                                  # writeShellApplication wrappers
  kitty.nix, nvim.nix, nvim/, tmux.nix,
  emacs.nix, emacs/                               # terminal/editor/multiplexer
  browser.nix, gtk.nix, gtk/, qt.nix,
  spotify.nix, starship.nix, thunderbird.nix,
  tofi.nix, vesktop.nix, vesktop/                   # remaining homeManager-only aspects
  utils.nix                                          # exposes `utils` module arg
                                                       # (dotfiles path + symlink helper)
```

## Commands

```sh
just switch          # nixos-rebuild switch --flake . (needs a password - run it yourself)
just build            # nixos-rebuild build (no activation) - safe to verify a change
just check              # nix flake check
just fmt                  # format all files (treefmt)
just update                 # update flake inputs, commit the lockfile
just clean                    # gc generations older than 7 days, optimise the store
just repair                     # verify and repair the Nix store (alias: just fix)
just deploy <host>                 # switch a remote host over SSH
just install <host>                   # provision a fresh host via nixos-anywhere
just rotate                             # rotate SOPS secrets (secrets/*.yaml)
```

Run `just` with no arguments to list all recipes.

## Notes

- `style` (from `lib/style.nix`) is threaded as `specialArgs`/`extraSpecialArgs`
  to every module - no explicit passing needed. It's a *build-time* seed only,
  derived from `themes/mocha.toml`; most apps get their live colors from the
  separate **runtime theme engine** instead (`theme-set <name>`, no rebuild
  needed - see `modules/theme-engine.nix`).
- App configs are symlinked directly from the repo via `mkOutOfStoreSymlink`
  (`utils.create_symlink`), so structural edits take effect immediately;
  Nix-generated/templated files (and the theme engine's own templates) still
  need a rebuild or `theme-set reapply`.
- Vesktop uses a custom Vencord build patched at build time with userplugins
  pulled from the `vesktop-plugins` flake input
  ([isneru/vesktop-custom-plugins](https://github.com/isneru/vesktop-custom-plugins)).
- Secrets are SOPS-encrypted in `secrets/`. Rotate with `just rotate`.
