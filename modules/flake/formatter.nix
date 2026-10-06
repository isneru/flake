{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree.override {
        runtimeInputs = with pkgs; [
          keep-sorted
          deadnix
          nixfmt
          ruff
          shfmt
          stylua
        ];
        settings = {
          on-unmatched = "info";
          tree-root-file = "flake.nix";
          excludes = [ "secrets/*" ];

          formatter = {
            deadnix = {
              command = "deadnix";
              options = [ "--edit" ];
              includes = [ "*.nix" ];
            };
            keep-sorted = {
              command = "keep-sorted";
              includes = [ "*" ];
            };
            nixfmt = {
              command = "nixfmt";
              includes = [ "*.nix" ];
            };
            ruff-check = {
              command = "ruff";
              options = [
                "check"
                "--fix"
              ];
              includes = [ "*.py" ];
            };
            ruff-format = {
              command = "ruff";
              options = [ "format" ];
              includes = [ "*.py" ];
              priority = 1;
            };
            shfmt = {
              command = "shfmt";
              options = [
                "-s"
                "-w"
                "-i"
                "2"
              ];
              includes = [
                "*.sh"
                "*.envrc"
              ];
            };
            stylua = {
              command = "stylua";
              includes = [ "*.lua" ];
            };
            typstyle = {
              command = "typstyle";
              includes = [ "*.typ" ];
            };
          };
        };
      };
    };
}
