{ ... }:

{
  catppuccin.thunderbird.profile = "default";

  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
    };
  };
}
