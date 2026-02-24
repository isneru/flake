{ ... }:

{
programs.firefox = {
  enable = true;
  profiles.neru = {
    settings = {
      "browser.compactmode.show" = true;
      "browser.uidensity" = 1;
      "browser.tabs.inTitlebar" = 1;
    };
    userChrome = ''
      #TabsToolbar { visibility: collapse !important; }
    '';
  };
};
}