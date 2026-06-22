{ ... }:
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = true;
        show_symlink = true;
        ratio = [
          1
          3
          4
        ];
      };
    };
  };
}
