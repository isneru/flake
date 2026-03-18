{ lib, useAmbxst, ... }:

{
  config = lib.mkIf useAmbxst {
    xdg.configFile."ambxst" = {
      source = ./.;
      recursive = true;
    };
  };
}
