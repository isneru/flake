#!/usr/bin/env bash
set -euo pipefail

FLAKE_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="${FLAKE_ROOT}/README.md"

declare -A INPUT_DESC=(
  [flake-parts]="Flake organization"
  [helium]="Helium browser"
  [home-manager]="User environment management"
  [lanzaboote]="Secure Boot"
  [niri]="Niri window manager"
  [nixpkgs]="Packages and NixOS modules"
  [sops-nix]="Secrets management"
  [spicetify]="Spotify theming"
)

inputs_table() {
  local metadata
  metadata=$(nix flake metadata --json "$FLAKE_ROOT")

  echo "| Input | Purpose |"
  echo "|-------|---------|"

  while IFS= read -r entry; do
    local name node desc url
    name=$(printf '%s' "$entry" | jq -r '.key')
    node=$(printf '%s' "$entry" | jq -r '.value')
    desc="${INPUT_DESC[$name]:-}"
    [[ -z "$desc" ]] && continue

    url=$(printf '%s' "$metadata" | jq -r "
      .locks.nodes[\"$node\"].original |
      if .type == \"github\" then \"https://github.com/\" + .owner + \"/\" + .repo
      elif .url then .url
      else \"\" end
    ")

    printf '| [%s](%s) | %s |\n' "\`${name}\`" "$url" "$desc"
  done < <(printf '%s' "$metadata" | jq -c '.locks.nodes.root.inputs | to_entries | sort_by(.key)[]')
}

{
  cat << 'EOF'
# neru's flake

NixOS configuration flake for a minimal Wayland desktop built around Niri, Ghostty, Neovim.

> [!NOTE]
> This configuration is tinkered for my personal needs and hardware (just a single laptop). It is shared as reference and inspiration, not as a drop-in config. You will need to adapt it to your own system.

## Preview

<details>
<summary>Overview</summary>

![Overview](assets/preview/overview.png)
</details>

<details>
<summary>Spotify</summary>

![Spotify](assets/preview/spotify.png)
</details>

<details>
<summary>Tofi</summary>

![Tofi](assets/preview/tofi.png)
</details>

<details>
<summary>Wallpaper and waybar</summary>

![Wallpaper and waybar](assets/preview/wallpaper_waybar.png)
</details>

## What's inside

| Layer | Component |
|-------|-----------|
| Window Manager | Niri (Wayland) |
| Terminal | Ghostty |
| Shell | Zsh + Oh My Zsh + Starship |
| Editor | Neovim (LSP, Telescope, Tree-sitter) |
| Multiplexer | Tmux (sessionx, resurrect) |
| Status Bar | Waybar |
| App Launcher | Tofi |
| Music | Spotify + Spicetify |
| File Manager | Thunar |
| PDF Viewer | Zathura |

Colors, fonts, and theme settings are centralized:

- **`colors.nix`** — color palette, shared across all apps
- **`fonts.nix`** — Primary and fallback monospace fonts, shared across all apps

## Installation

1. Install [NixOS](https://nixos.org/download/) and boot into a minimal environment.

2. Clone this repo:
   ```sh
   git clone https://github.com/isneru/flake ~/flake
   ```

3. Replace the hardware configuration with your own:
   ```sh
   cp /etc/nixos/hardware-configuration.nix ~/flake/hosts/victus/hardware.nix
   ```

4. Build and switch:
   ```sh
   cd ~/flake
   just switch
   ```

   Or without `just`:
   ```sh
   nixos-rebuild switch --flake ~/flake
   ```

## Dependencies

### External fonts

The following fallback fonts are installed via Nix:
- IosevkaTerm Nerd Font
- CaskaydiaCove Nerd Font
- JetBrains Mono Nerd Font
- Geist Mono Nerd Font
- Fira Code Nerd Font

### Flake inputs

EOF
  inputs_table
  cat << 'EOF'

### Other

- A wallpaper at `~/Pictures/wallpapers/wallhaven_l3xk6q.jpg` (referenced by swaybg)

## Structure

```
flake/
├── flake.nix              # Entrypoint and inputs
├── parts/                 # Flake-parts modules (formatter, nixos)
├── hosts/victus/          # Host-specific config (hardware, boot, desktop)
├── home/neru/
│   ├── colors.nix         # Centralized color palette
│   ├── fonts.nix          # Centralized font config
│   ├── theme.nix          # GTK/Qt/cursor theming
│   ├── cli.nix            # Shell, zoxide, zathura
│   ├── packages.nix       # System-wide packages
│   └── config/
│       ├── ghostty/       # Terminal
│       ├── niri/          # Window manager
│       ├── waybar/        # Status bar
│       ├── nvim/          # Neovim (LSP, plugins, theme)
│       ├── tmux/          # Tmux + plugins
│       ├── spotify/       # Spicetify
│       ├── tofi/          # App launcher
│       ├── starship/      # Shell prompt
│       └── vesktop/       # Discord client
└── secrets/               # Encrypted secrets (sops)
```
EOF
} >"$README"

echo "README.md updated."
