flake := env('FLAKE', justfile_directory()) 
rebuild := if os() == "macos" { "sudo darwin-rebuild" } else { "nixos-rebuild" }
system-args := if os() == "macos" { "" } else { "--sudo --no-reexec" }

[private]
default:
    @just --list

[group('rebuild')]
[private]
builder goal *args:
    {{ rebuild }} {{ goal }} \
      --flake {{ flake }} \
      {{ system-args }} \
      {{ args }}

[group('rebuild')]
switch *args: (builder "switch" args)

[group('rebuild')]
deploy host *args: (builder "switch" "--target-host " + host "--use-substitutes " + args)

[group('rebuild')]
install host:
  nix run github:nix-community/nixos-anywhere -- \
    --flake {{ flake }} \
    --target-host {{ host }}

[group('rebuild')]
[macos]
provision host:
  sudo nix run github:nix-darwin/nix-darwin -- switch --flake {{ flake }}#{{ host }}
  sudo -i nix-env --uninstall lix

[group('utils')]
clean:
    nix-collect-garbage --delete-older-than 3d
    nix store optimise

[group('utils')]
rotate:
  find secrets/ -name "*.yaml" | xargs -I {} sops rotate -i {}
  find secrets/ -name "*.yaml" | xargs -I {} sops updatekeys -y {}

[group('utils')]
update:
  nix flake update \
    --commit-lock-file \
    --commit-lockfile-summary "flake: update inputs" \
    --flake {{ flake }}

alias fix := repair

[group('utils')]
repair:
  nix-store --verify --check-contents --repair

[group('vm')]
[macos]
run-vm:
  nix run .#nixosConfigurations.vm.config.system.build.vm