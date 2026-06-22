{
  pkgs,
  utils,
  ...
}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withRuby = false;
    withPython3 = false;
    sideloadInitLua = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    plugins = with pkgs.vimPlugins; [
      # keep-sorted start
      catppuccin-nvim
      cmp-buffer
      cmp-nvim-lsp
      cmp-nvim-lua
      cmp-path
      cmp_luasnip
      conform-nvim
      dashboard-nvim
      flash-nvim
      harpoon2
      lualine-nvim
      luasnip
      mini-nvim
      nvim-cmp
      nvim-highlight-colors
      nvim-lspconfig
      nvim-treesitter-textobjects
      nvim-treesitter.withAllGrammars
      oil-nvim
      plenary-nvim
      render-markdown-nvim
      snacks-nvim
      tabout-nvim
      telescope-fzf-native-nvim
      telescope-nvim
      treesj
      typst-preview-nvim
      vim-tpipeline
      vimtex
      which-key-nvim
      # keep-sorted end
    ];
    extraPackages = with pkgs; [
      # keep-sorted start
      astro-language-server
      bash-language-server
      clang-tools
      curl
      emmet-language-server
      fd # Required by Telescope for fast file finding
      ffmpeg
      imagemagick
      jdt-language-server
      lua-language-server
      markdown-oxide
      mermaid-cli
      nil
      nixd
      nixfmt
      prettier
      prettierd
      ripgrep # Required by Telescope for fast text searching
      rust-analyzer
      tailwindcss-language-server
      taplo
      texlab
      texliveMedium
      tinymist
      vscode-langservers-extracted
      vtsls
      websocat
      wl-clipboard # For Wayland clipboard support (use xclip if on X11)
      yaml-language-server
      # keep-sorted end
    ];
  };

  xdg.configFile."nvim".source = utils.create_symlink "${utils.dotfiles}/nvim/";
}
