# flake

NixOS + Home Manager configuration for `victus`, structured as a **dendritic
flake-parts tree**: every `.nix` file under `modules/` is a self-contained,
self-registering module, auto-discovered by `import-tree` - there's no manual
`imports = [ ... ]` list anywhere in `modules/`. A feature that spans both
layers (e.g. Hyprland: compositor enable at the NixOS level, config +
theme registration at the Home Manager level) declares both in one file
instead of being split across a system/user directory boundary.

Hyprland under UWSM, SDDM wearing the same face as the lock screen, and a
Quickshell shell that owns the desktop's notifications, lock screen, polkit
prompts, credential prompts, screen-share picker and tray. It is deliberately
plain: one status line along the bottom, a themed `wmenu` for every choice, and
flat cards only where something needs an answer. The Omen key switches the
whole desktop between a **flat** look (square, translucent, blurred, still
layers) and a **soft** one (rounded, opaque, animated layers). Colours are
runtime, not build-time: `neru theme <name>` repaints almost everything without
a rebuild.

## Structure

```
flake.nix                                      # entry point: inputs + flake-parts + import-tree ./modules
hosts/victus/                                  # host identity + hardware - not a pooled aspect
  default.nix                                  # hostName, networking, users, GPU workarounds
  hardware.nix                                 # nixos-generate-config output
modules/                                       # one directory per aspect: <name>/<name>.nix
                                               # plus whatever files it reads or symlinks
  flake/                                       # the flake's own assembly, not aspects
    system.nix                                 # nixosConfigurations.victus assembly
    checks.nix                                 # theme-render check (see below)
    formatter.nix                              # treefmt (nixfmt, deadnix, stylua, shfmt, keep-sorted)
    apps.nix, lib.nix                          # nix run .#<app> standalone previews
  boot/, locales/, nix/, coredump/, secrets/   # nixos-only aspects
  desktop/                                     # portals, power, bluetooth
  networking/                                  # NetworkManager, BBR, wireshark
  virtualisation/                              # libvirt + virt-manager (the Proxmox lab VM)
  sddm/                                        # SDDM (Xorg-hosted greeter) wearing a theme
                                               # built from the lock screen's own QML
  auth/                                        # bare-askpass: ssh, git and sudo prompts
                                               # routed into the shell (nixos + homeManager)
  screencast/                                  # bare-share-picker: the screen-share
                                               # picker xdg-desktop-portal-hyprland raises
  hyprland/                                    # compositor: nixos enable + homeManager
                                               # config (Lua, live-edited via symlink)
  neru/                                        # the one command on PATH: every script
                                               # is a `neru <command>` (`neru help`)
  theme-engine/                                # runtime theming system - neru theme,
                                               # theme_engine.py, themes/*.toml
  quickshell/                                  # the shell (QML) - see below, plus its
                                               # lock screen's PAM service and hypridle
  bare/                                        # the menus: neru menu (themed wmenu,
                                               # patched for image previews), neru pick
                                               # (the menus), neru look (flat / soft)
  gaming/                                      # RTX 3050 Ti under PRIME offload, Steam
                                               # and gamescope, the gamerun wrapper
  calendar/                                    # Google Calendar sync (neru cal + timer)
                                               # feeding the agenda, and course deadlines
                                               # pushed from Markdown files on save
  audio/, files/, localsend/                   # remaining service aspects
  cli/, packages/, appearance/, cursor/,
  icons/, scripts/                             # shell/fonts/cursor/icons/ad-hoc packages,
                                               # writeShellApplication wrappers
  neovim/                                      # nixvim, and the $EDITOR/$VISUAL contract
  music/                                       # mpd + rmpc, local files, MPRIS into the shell
  kitty/, browser/, gtk/, qt/, starship/,
  vesktop/                                     # remaining homeManager-only aspects
  utils/                                       # exposes `utils` module arg
                                               # (dotfiles path + symlink helper)
scripts/                                       # every shell and Python script, as
                                               # scripts/<name>/, read by modules/<name>/
```

## The shell

`modules/quickshell/` is a Quickshell/QML shell with one status line along the
bottom: workspaces, the focused app (or qutebrowser's and yazi's own status
line while they have focus), and on the right whatever is going on - a
recording, a transfer, a download, the next event, the timer, muted, do not
disturb, night light, the mic in use - then weather, battery, network and the
clock. Every segment is clickable. It owns the desktop's notification server,
lock screen, polkit agent, screen-share picker and system tray, and every part
of it is backed by a real service - PipeWire, MPRIS, UPower, NetworkManager,
bluez, cliphist, StatusNotifier, open-meteo, PAM, polkit, xdg-desktop-portal,
Hyprland's IPC - with nothing mocked.

- **Choices are menus.** `neru pick <source>` opens a themed `wmenu` for each
  of them: apps (or a web search), windows, clipboard, wallpaper, theme, media
  controls, power and profiles, Wi-Fi, Bluetooth, audio, displays, calendar,
  course deadlines, notes, the timer, the files shelf, LocalSend, the tray (an
  app, then its own right-click menu), and a calculator REPL. `SUPER+B` lists
  them all.
- **wmenu is patched** to draw an image preview beside the list, to centre a
  list as a box, and to show a transcript without filtering it.
- **Things that need an answer are flat cards**: password prompts, the
  screen-share picker and incoming files. The lock screen has its own face.
  Notifications and OSDs draw above fullscreen windows; there is no
  notification history.
- **Things with nothing to pick are popups** above the bar: the clock, the
  weather, battery details, the system monitor, network stats. `SUPER+?` opens
  a cheatsheet card.

```
shell.qml       # ShellRoot: the bar per screen, the OSD and cards, the session lock, every IPC target
singletons/     # state, theme tokens, and the service wrappers
bare/           # the surfaces: bar, OSD, popup, prompt cards, cheatsheet
lock/           # the session lock surface and its face (also the SDDM greeter's)
components/     # the icon glyph the Moodle app shares
```

Driven by keybinds or over IPC:

| Keys                        | Action                          |
| --------------------------- | ------------------------------- |
| `SUPER+B`                   | every menu                      |
| `SUPER+space`               | launcher, or `?query` to search |
| `Calculator`                | calculator                      |
| `SUPER+V` / `SUPER+SHIFT+V` | clipboard / files shelf         |
| `SUPER+A`                   | wallpaper                       |
| `SUPER+SHIFT+T`             | timer                           |
| `SUPER+M` / `SUPER+TAB`     | media controls / windows        |
| `SUPER+O`                   | overview of every workspace     |
| `SUPER+Escape`              | power and profiles              |
| `SUPER+T`                   | tray                            |
| `SUPER+?`                   | keybinding cheatsheet           |
| `SUPER+CTRL+L`              | lock                            |
| `Omen`                      | the flat look and the soft one  |
| `SUPER+D`                   | Discord and music pad           |

```sh
neru pick                         # list every menu
neru pick wifi                    # open one from a terminal
quickshell ipc call bare osd vol
quickshell ipc call look toggle
quickshell ipc call timer start 300
```

QML is symlinked from the repo, so edits apply on save with no rebuild.

## Theming

The theme engine (`neru theme <name>`) renders each app's config from a
template and reloads it in place. Hyprland, kitty, Neovim, vesktop, rmpc,
GTK, Qt, SDDM and the shell all follow it without a rebuild.

A theme is a palette and a font, nothing else - no wallpaper, no radius, no
light/dark flag. The wallpaper is your own pick (`neru theme wallpaper <path>`,
or the wallpaper menu) and persists across theme switches, re-tinted
to each theme's accent unless you pass `--no-recolor`. The wallpaper menu also
lists Gustave Doré's engravings, which are always dithered to two tones of the
current theme.

Adding a theme means dropping a `.toml` into `modules/theme-engine/themes/`;
`just check` renders every theme against every template and fails on a missing
key or a leftover `{{token}}`.

## Installing on a new machine

The flake describes one machine (`victus`) and one user (`neru`). To install it
somewhere else, rename those and delete the parts that only make sense here.

1. Boot the NixOS installer, partition, and mount the target at `/mnt`.
2. Clone into the new user's home - **it has to be `~/flake`**, because the shell,
   Hyprland and the other live-edited configs are symlinks into that checkout:
   ```sh
   git clone https://github.com/isneru/flake /mnt/home/<user>/flake
   cd /mnt/home/<user>/flake
   ```
3. Delete what is personal to this machine's owner - each is one directory, plus its
   scripts under `scripts/`:
   ```sh
   git rm -r modules/{calendar,isep-site,phone,moodle,sc,mic,wireguard} modules/packages/personal.nix scripts/{calendar,phone,moodle,mic,packages}
   ```
   and, unless you set them up, `modules/secureboot` (needs `sbctl create-keys` and the
   keys enrolled in firmware) and `modules/gaming` (needs NVIDIA hybrid graphics).
   Without `calendar`, `isep-site` and `sc` nothing reads `secrets/`, so no sops key is needed.
   `modules/whatsapp` (a WhatsApp client you link to your own account) and
   `modules/claude` (Claude Code skills) are optional - delete them if you do not use them.
   `modules/packages/optional.nix` is tools nothing else in the flake calls - keep,
   trim or empty it to taste; `core.nix` beside it is what the shell and scripts need.
4. Rename the user and the host. Every place that needs it:
   ```sh
   git mv hosts/victus hosts/<host>
   sed -i 's/\bneru\b/<user>/g' hosts/<host>/default.nix modules/flake/system.nix \
     modules/sddm/sddm.nix modules/virtualisation/virtualisation.nix
   sed -i 's/\bvictus\b/<host>/g' hosts/<host>/default.nix modules/flake/system.nix \
     modules/neovim/neovim.nix
   ```
   If you kept `calendar`, `isep-site` or `phone`, rename in `modules/calendar/calendar.nix`,
   `modules/isep-site/isep-site.nix` and `modules/phone/phone.nix` too. Other matches
   for `neru` (`lua/neru/` in Neovim, `--neru-surface` in the Vesktop theme) are
   internal names - leave them.
5. Replace the hardware file, and edit `hosts/<host>/default.nix`: timezone, keyboard
   layout, and drop what belongs to this laptop (the `hardware.nvidia.prime` bus IDs,
   the `i915` initrd module, the `nouveau` blacklist):
   ```sh
   nixos-generate-config --root /mnt --show-hardware-config > hosts/<host>/hardware.nix
   ```
6. `git add -A` (the flake cannot see untracked files), then install and give the
   user a password (SDDM logs in automatically, but the lock screen and `sudo` ask for
   it):
   ```sh
   nixos-install --flake .#<host>
   nixos-enter --root /mnt -c 'passwd <user>'
   nixos-enter --root /mnt -c 'chown -R <user>:users /home/<user>/flake'
   ```

## Commands

```sh
just switch          # nixos-rebuild switch --flake . (needs a password - run it yourself)
just build           # nixos-rebuild build (no activation) - safe to verify a change
just check           # nix flake check
just fmt             # format all files (treefmt)
just update          # update flake inputs, commit the lockfile
just clean           # gc generations older than 7 days, optimise the store
just repair          # verify and repair the Nix store (alias: just fix)
just deploy <host>   # switch a remote host over SSH
just secrets         # decrypt/edit secrets/secrets.yaml with sops
just rotate          # rotate SOPS secrets (secrets/*.yaml)
```

Run `just` with no arguments to list all recipes.

## Notes

- Source files carry no comments at all.
- App configs are symlinked directly from the repo via `mkOutOfStoreSymlink`
  (`utils.create_symlink`), so structural edits take effect immediately;
  Nix-generated and templated files still need a rebuild or `neru theme reapply`.
- `nix run github:isneru/flake#kitty` (also `#quickshell`, `#btop`, `#shell`)
  starts either app with this config and a theme of your choice, with no
  checkout and nothing written to your `$HOME`.
- The dGPU is opt-in per launcher: prefix a game with `gamerun` (or
  `gamerun %command%` in Steam). Nothing infers "this is a game", and the
  launcher deliberately wraps nothing.
- Screen sharing is the shell's too: `xdg-desktop-portal-hyprland` is pointed at
  a picker that draws in the shell. It also absorbs the burst - a Chromium app
  opens two or three portal sessions for one share, so picking a source used to
  mean answering the picker two or three times over.
- Vesktop uses a custom Vencord build patched at build time with userplugins
  pulled from the `vesktop-plugins` flake input
  ([isneru/vesktop-custom-plugins](https://github.com/isneru/vesktop-custom-plugins)).
- Window frames, the Umber, Vellum, Orpiment and Cinnabar themes and the
  dithered Doré plates are modelled on
  [athanor](https://github.com/script-wizards/athanor) by Script Wizards (MIT).
  Its Hyprland plugin is kept in `modules/hyprland/frame-plugin/` with its
  licence and built against the system's own Hyprland, so it never needs
  rebuilding by hand; the plates (public domain, sources in `plates.toml`) are
  in `modules/theme-engine/plates/`.
- Secrets are SOPS-encrypted in `secrets/`. Rotate with `just rotate`.
