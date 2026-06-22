# flake

NixOS + Home Manager configuration for `victus`.

## Structure

```
flake.nix                  # entry point, wires inputs via flake-parts
parts/
  nixos.nix                # nixosConfigurations.victus + Home Manager as NixOS module
  formatter.nix            # treefmt (nixfmt, deadnix, stylua, shfmt, keep-sorted)
hosts/victus/              # hardware, boot, networking, users
home/neru/
  style.nix                # Catppuccin Mocha palette + fonts, exposed as `style` module arg
  theme.nix                # GTK/Qt/cursor theming
  cli.nix                  # zsh, oh-my-zsh, zoxide, zathura
  packages.nix             # ad-hoc user packages
  scripts/                 # shell scripts (battery notify, screenshot, power menu)
  config/
    applets/               # GTK4 layer-shell applets (audio, wifi, bluetooth)
    driftwm/               # window manager config + shaders
    ghostty/               # terminal
    kitty/                 # terminal
    nvim/                  # neovim
    swaync/                # notification daemon
    tmux/                  # multiplexer
    vesktop/               # Discord (Vesktop + custom Vencord build with BypassDnD plugin)
    widgets/               # status bar widgets
    yazi/                  # file manager
    ...
```

## Commands

```sh
just switch          # nixos-rebuild switch --flake .
just fmt             # format all files
just update          # update flake inputs and commit lockfile
just clean           # gc generations older than 3 days
just deploy <host>   # switch a remote host over SSH
```

## Notes

- `style` is passed as `_module.args` to every Home Manager module - no explicit passing needed.
- App configs in `config/` are symlinked directly from the repo via `mkOutOfStoreSymlink`, so edits take effect without rebuilding.
- Vesktop uses a custom Vencord build that injects a userplugin ([vesktop-bypass-shouldNotify](https://github.com/isneru/vesktop-bypass-shouldNotify)) at compile time via `builtins.fetchGit`.
- Secrets are SOPS-encrypted in `secrets/`. Rotate with `just rotate`.
