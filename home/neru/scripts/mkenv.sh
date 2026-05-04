#!/usr/bin/env bash
set -euo pipefail

flake="/home/neru/flake"

selected=$(
  nix flake show --json "$flake" 2>/dev/null \
    | jq -r '.devShells."x86_64-linux" | keys[]' \
    | fzf --prompt="devshell > "
)

if [[ -z "$selected" ]]; then
  exit 0
fi

echo "use flake ${flake}#${selected}" > .envrc
direnv allow
