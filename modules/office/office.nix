{ ... }:
{
  flake.modules.homeManager.office =
    { lib, pkgs, ... }:
    {
      programs.onlyoffice.enable = true;

      xdg.dataFile = {
        "fonts/corefonts" = {
          source = "${pkgs.corefonts}/share/fonts/truetype";
          recursive = true;
        };
        "fonts/vista-fonts" = {
          source = "${pkgs.vista-fonts}/share/fonts/truetype";
          recursive = true;
        };
        "fonts/aptos" = {
          source = pkgs.fetchzip {
            name = "aptos";
            url = "https://download.microsoft.com/download/8/6/0/860a94fa-7feb-44ef-ac79-c072d9113d69/Microsoft%20Aptos%20Fonts.zip";
            stripRoot = false;
            hash = "sha256-jkYOP5upe+zMnuQtDLCAcaG1ocbx1iHm1ygW9pqGTig=";
          };
          recursive = true;
        };
      };

      xdg.mimeApps.defaultApplications =
        lib.genAttrs [
          "application/msword"
          "application/rtf"
          "application/vnd.ms-excel"
          "application/vnd.ms-excel.sheet.macroEnabled.12"
          "application/vnd.ms-powerpoint"
          "application/vnd.ms-powerpoint.presentation.macroEnabled.12"
          "application/vnd.ms-word.document.macroEnabled.12"
          "application/vnd.oasis.opendocument.presentation"
          "application/vnd.oasis.opendocument.spreadsheet"
          "application/vnd.oasis.opendocument.text"
          "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
          "application/vnd.openxmlformats-officedocument.presentationml.template"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
        ] (_: "onlyoffice-desktopeditors.desktop")
        // {
          "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
        };
    };
}
