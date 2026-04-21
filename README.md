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
| Multiplexer | Tmux (TPM, sessionx, resurrect) |
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

The primary font **IoskeleyMono Nerd Font** is not packaged in nixpkgs and must be installed manually (e.g. into `~/.local/share/fonts/`).

The following fallback fonts are installed via Nix:
- CaskaydiaCove Nerd Font
- JetBrains Mono Nerd Font
- Geist Mono Nerd Font
- Fira Code Nerd Font

### Flake inputs

| Input | Purpose |
|-------|---------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) (unstable) | Packages and NixOS modules |
| [home-manager](https://github.com/nix-community/home-manager) | User environment management |
| [flake-parts](https://github.com/hercules-ci/flake-parts) | Flake organization |
| [niri-flake](https://github.com/sodiboo/niri-flake) | Niri window manager |
| [spicetify-nix](https://github.com/Gerg-L/spicetify-nix) | Spotify theming |
| [lanzaboote](https://github.com/nix-community/lanzaboote) | Secure Boot |
| [sops-nix](https://github.com/Mic92/sops-nix) | Secrets management |

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

