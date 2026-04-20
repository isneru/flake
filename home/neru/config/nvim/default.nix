{ pkgs, utils, colors, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    plugins = with pkgs.vimPlugins; [
      cmp-buffer
      cmp-nvim-lsp
      cmp-path
      conform-nvim
      gitsigns-nvim
      lualine-nvim
      mini-nvim
      nvim-cmp
      nvim-lspconfig
      nvim-tree-lua
      nvim-treesitter.withAllGrammars
      plenary-nvim
      telescope-file-browser-nvim
      telescope-fzf-native-nvim
      telescope-nvim
      which-key-nvim
      base16-nvim
    ];
    extraPackages = with pkgs; [
      ripgrep # Required by Telescope for fast text searching
      fd # Required by Telescope for fast file finding
      wl-clipboard # For Wayland clipboard support (use xclip if on X11)
      astro-language-server
      bash-language-server
      emmet-language-server
      lua-language-server
      nil
      nixd
      nixfmt
      prettier
      rust-analyzer
      tailwindcss-language-server
      vtsls
      yaml-language-server
      taplo
      clang-tools
      jdt-language-server
    ];
  };

  xdg.configFile."nvim" = {
    source = utils.create_symlink "${utils.dotfiles}/nvim/";
    recursive = true;
  };

  xdg.dataFile."nvim/site/lua/neru/colors.lua".text = ''
    return {
      bg = "${colors.bg}", bgDim = "${colors.bgDim}", bgAlt = "${colors.bgAlt}", border = "${colors.border}",
      fg = "${colors.fg}", fgDim = "${colors.fgDim}", fgMuted = "${colors.fgMuted}",
      accent = "${colors.accent}", error = "${colors.error}", warning = "${colors.warning}", success = "${colors.success}", info = "${colors.info}",
      red = "${colors.red}", magenta = "${colors.magenta}", orange = "${colors.orange}", cyan = "${colors.cyan}", blue = "${colors.blue}", purple = "${colors.purple}",
    }
  '';
}
