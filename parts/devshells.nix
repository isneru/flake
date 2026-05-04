{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells = {
        c = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            gcc
            gdb
            gnumake
          ];
        };

        java = pkgs.mkShell {
          packages = with pkgs; [
            jetbrains.idea
            maven
          ];
        };

        typst = pkgs.mkShell {
          packages = with pkgs; [
            tinymist
            typst
            typst-live
          ];
        };

        diagrams = pkgs.mkShell {
          packages = with pkgs; [
            graphviz
            plantuml
          ];
        };

        net = pkgs.mkShell {
          packages = with pkgs; [
            inetutils
            iw
            nmap
            wavemon
          ];
        };

        r = pkgs.mkShell {
          packages = [
            (pkgs.rstudioWrapper.override {
              packages = with pkgs.rPackages; [
                dplyr
                ggplot2
                tidyverse
              ];
            })
          ];
        };
      };
    };
}
