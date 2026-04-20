{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree.override {
        runtimeInputs = with pkgs; [
          keep-sorted
          deadnix
          nixfmt
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
          };
        };
      };
    };
}
