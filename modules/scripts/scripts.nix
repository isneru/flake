{ lib, ... }:
let
  mkScripts = pkgs: {
    screenshot = pkgs.writeShellApplication {
      name = "screenshot";
      runtimeInputs = with pkgs; [
        grim
        slurp
        wl-clipboard
        satty
        wayfreeze
      ];
      text = builtins.readFile ./freeze.sh + builtins.readFile ./screenshot.sh;
    };
    ocr = pkgs.writeShellApplication {
      name = "ocr";
      runtimeInputs = with pkgs; [
        grim
        slurp
        tesseract
        wl-clipboard
        libnotify
        wayfreeze
      ];
      text = builtins.readFile ./freeze.sh + builtins.readFile ./ocr.sh;
    };
    qrscan = pkgs.writeShellApplication {
      name = "qrscan";
      runtimeInputs = with pkgs; [
        grim
        slurp
        wl-clipboard
        zbar
        wayfreeze
      ];
      text = builtins.readFile ./freeze.sh + builtins.readFile ./qrscan.sh;
    };
    record = pkgs.writeShellApplication {
      name = "record";
      runtimeInputs = with pkgs; [
        slurp
        wf-recorder
        libnotify
        pipewire
        procps
        wireplumber
      ];
      text = builtins.readFile ./record.sh;
    };
    colorpicker = pkgs.writeShellApplication {
      name = "colorpicker";
      runtimeInputs = with pkgs; [
        hyprpicker
        libnotify
      ];
      text = builtins.readFile ./colorpicker.sh;
    };
    ns = pkgs.writeShellApplication {
      name = "ns";
      runtimeInputs = with pkgs; [
        fzf
        (nix-search-tv.overrideAttrs {
          env.GOEXPERIMENT = "jsonv2";
          allowGoReference = true;
        })
      ];
      text = ''exec "${pkgs.nix-search-tv.src}/nixpkgs.sh" "$@"'';
    };
  };

  portable = [
    # keep-sorted start
    "colorpicker"
    "ns"
    "ocr"
    "record"
    "screenshot"
    # keep-sorted end
  ];
in
{
  flake.previews = lib.genAttrs portable (name: {
    aspects = [ ];
    build = { pkgs, ... }: (mkScripts pkgs).${name};
  });

  flake.modules.homeManager.scripts =
    { pkgs, ... }:
    {
      home.packages = lib.attrValues (mkScripts pkgs);
    };
}
