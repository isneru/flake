{
  pkgs,
  utils,
  colors,
  ...
}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    plugins = with pkgs.vimPlugins; [
      # keep-sorted start
      base16-nvim
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
      # keep-sorted end
      (pkgs.vimUtils.buildVimPlugin {
        name = "md-render";
        src = pkgs.fetchFromGitHub {
          owner = "delphinus";
          repo = "md-render.nvim";
          rev = "75d976d89edc4b9457447ba83201ec5805600f79";
          hash = "sha256-Te4I0xtSjpLn7c5dLti12w/I0NT4oCUm/sEQAcyNQuU=";
        };
      })
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
      jdt-language-server
      lua-language-server
      mermaid-cli
      nil
      nixd
      nixfmt
      prettier
      ripgrep # Required by Telescope for fast text searching
      rust-analyzer
      tailwindcss-language-server
      taplo
      vtsls
      wl-clipboard # For Wayland clipboard support (use xclip if on X11)
      yaml-language-server
      # keep-sorted end
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
