flake := env('FLAKE', justfile_directory())
rebuild := "nixos-rebuild"
system-args := "--sudo --no-reexec"

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
check:
    nix flake check {{ flake }}

[group('rebuild')]
build:
    nixos-rebuild build --flake {{ flake }}

[group('rebuild')]
deploy host *args: (builder "switch" "--target-host " + host + " --use-substitutes " + args)

[group('utils')]
clean:
    nix-collect-garbage --delete-older-than 7d
    nix store optimise

[group('utils')]
secrets:
  sops secrets/secrets.yaml

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

[group('utils')]
fmt:
  nix fmt
