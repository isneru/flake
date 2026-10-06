{ ... }:
{
  flake.modules.nixos.neovim =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.micro ];
      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    };

  flake.modules.homeManager.neovim =
    {
      inputs,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      flake = dirOf utils.dotfiles;

      textTypes = [
        # keep-sorted start
        "application/json"
        "application/sql"
        "application/toml"
        "application/x-shellscript"
        "application/x-tiled-tsx"
        "application/x-yaml"
        "application/xml"
        "application/yaml"
        "text/css"
        "text/csv"
        "text/english"
        "text/javascript"
        "text/markdown"
        "text/plain"
        "text/rust"
        "text/vnd.trolltech.linguist"
        "text/x-c"
        "text/x-c++"
        "text/x-c++hdr"
        "text/x-c++src"
        "text/x-chdr"
        "text/x-csrc"
        "text/x-diff"
        "text/x-go"
        "text/x-java"
        "text/x-log"
        "text/x-lua"
        "text/x-makefile"
        "text/x-patch"
        "text/x-perl"
        "text/x-python"
        "text/x-qml"
        "text/x-readme"
        "text/x-sql"
        "text/x-tex"
        "text/xml"
        # keep-sorted end
      ];

    in
    {
      imports = [ inputs.nixvim.homeModules.nixvim ];

      programs.nixvim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
        defaultEditor = false;

        nixpkgs = {
          source = inputs.nixpkgs;
          config.allowUnfreePredicate = pkg: lib.getName pkg == "vim-be-good";
        };

        globals = {
          loaded_netrw = 1;
          loaded_netrwPlugin = 1;
          mapleader = " ";
          maplocalleader = " ";
        };

        clipboard = {
          register = "unnamedplus";
          providers.wl-copy.enable = true;
        };

        opts = {
          number = true;
          showtabline = 0;
          relativenumber = true;
          wrap = false;
          cmdheight = 0;
          cursorline = true;
          cursorlineopt = "number";
          signcolumn = "no";
          fillchars = {
            eob = " ";
          };
          scrolloff = 8;
          tabstop = 4;
          shiftwidth = 4;
          expandtab = true;
          smartindent = true;
          ignorecase = true;
          smartcase = true;
          splitbelow = true;
          splitright = true;
          undofile = true;
          termguicolors = true;
          updatetime = 200;
          title = true;
        };

        extraFiles = builtins.listToAttrs (
          map
            (n: {
              name = "lua/neru/${n}.lua";
              value.source = ./lua/neru + "/${n}.lua";
            })
            [
              # keep-sorted start
              "buffers"
              "colors"
              "init"
              "lsp"
              "numbers"
              "statusline"
              "tree"
              "ui"
              # keep-sorted end
            ]
        );

        extraPackages = with pkgs; [
          # keep-sorted start
          clang-tools
          nixfmt
          prettier
          python3Packages.pylatexenc
          ruff
          shfmt
          stylua
          typstyle
          # keep-sorted end
        ];

        extraConfigLua = ''require("neru").setup()'';

        diagnostic.settings.signs = false;

        plugins = {
          web-devicons.enable = true;
          treesitter.enable = true;
          which-key.enable = true;
          guess-indent.enable = true;

          rainbow-delimiters = {
            enable = true;
            settings.highlight = [
              "RainbowDelimiter1"
              "RainbowDelimiter2"
              "RainbowDelimiter3"
              "RainbowDelimiter4"
              "RainbowDelimiter5"
              "RainbowDelimiter6"
            ];
          };

          lsp = {
            enable = true;
            inlayHints = true;
            keymaps.lspBuf = {
              gd = "definition";
              gD = "declaration";
              gr = "references";
              gi = "implementation";
              gy = "type_definition";
              K = "hover";
              "<leader>rn" = "rename";
              "<leader>ca" = "code_action";
            };
            servers = {
              astro.enable = true;
              bashls.enable = true;
              clangd.enable = true;
              cssls.enable = true;
              gopls.enable = true;
              html.enable = true;
              jdtls.enable = true;
              jsonls.enable = true;
              lua_ls = {
                enable = true;
                settings = {
                  runtime.version = "LuaJIT";
                  diagnostics.globals = [ "vim" ];
                  workspace = {
                    checkThirdParty = false;
                    library.__raw = "{ vim.env.VIMRUNTIME .. '/lua' }";
                  };
                };
              };
              marksman.enable = true;
              nixd = {
                enable = true;
                settings = {
                  nixpkgs.expr = "(builtins.getFlake \"${flake}\").inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}";
                  formatting.command = [ "nixfmt" ];
                  options = {
                    nixos.expr = "(builtins.getFlake \"${flake}\").nixosConfigurations.victus.options";
                    home-manager.expr = "(builtins.getFlake \"${flake}\").nixosConfigurations.victus.options.home-manager.users.type.getSubOptions [ ]";
                  };
                };
              };
              prismals.enable = true;
              pyright.enable = true;
              ruff.enable = true;
              rust_analyzer = {
                enable = true;
                installCargo = true;
                installRustc = true;
              };
              svelte.enable = true;
              tailwindcss.enable = true;
              taplo.enable = true;
              texlab.enable = true;
              tinymist.enable = true;
              vtsls.enable = true;
              vue_ls.enable = true;
              yamlls.enable = true;
            };
          };

          blink-cmp = {
            enable = true;
            settings = {
              keymap.preset = "super-tab";
              signature.enabled = true;

              appearance.kind_icons = {
                Text = "";
                Method = "";
                Function = "";
                Constructor = "";
                Field = "";
                Variable = "";
                Property = "";
                Class = "";
                Interface = "";
                Struct = "";
                Module = "";
                Unit = "";
                Value = "";
                Enum = "";
                EnumMember = "";
                Keyword = "";
                Constant = "";
                Snippet = "";
                Color = "";
                File = "";
                Reference = "";
                Folder = "";
                Event = "";
                Operator = "";
                TypeParameter = "";
              };

              completion = {
                ghost_text.enabled = true;

                documentation = {
                  auto_show = true;
                  auto_show_delay_ms = 250;
                  window = {
                    border = "padded";
                    desired_min_width = 30;
                    max_width = 70;
                  };
                };

                menu = {
                  border = "none";
                  max_height = 14;
                  draw = {
                    treesitter = [ "lsp" ];
                    columns = [
                      { __unkeyed-1 = "kind_icon"; }
                      {
                        __unkeyed-1 = "label";
                        __unkeyed-2 = "label_description";
                        __unkeyed-3 = "kind";
                        gap = 1;
                      }
                    ];
                    components.kind = {
                      width.fill = false;
                      highlight = "BlinkCmpKind";
                    };
                  };
                };
              };

              sources.providers = {
                buffer = {
                  min_keyword_length = 4;
                  max_items = 5;
                };
                snippets.score_offset = 0;
              };
            };
          };

          conform-nvim = {
            enable = true;
            settings = {
              format_on_save = {
                lsp_format = "fallback";
                timeout_ms = 2000;
              };
              formatters_by_ft = {
                astro = [ "prettier" ];
                c = [ "clang-format" ];
                cpp = [ "clang-format" ];
                css = [ "prettier" ];
                go = [ "gofmt" ];
                html = [ "prettier" ];
                javascript = [ "prettier" ];
                javascriptreact = [ "prettier" ];
                json = [ "prettier" ];
                lua = [ "stylua" ];
                markdown = [ "prettier" ];
                nix = [ "nixfmt" ];
                python = [ "ruff_format" ];
                rust = [ "rustfmt" ];
                scss = [ "prettier" ];
                sh = [ "shfmt" ];
                svelte = [ "prettier" ];
                typescript = [ "prettier" ];
                typescriptreact = [ "prettier" ];
                typst = [ "typstyle" ];
                vue = [ "prettier" ];
                yaml = [ "prettier" ];
              };
            };
          };

          telescope = {
            enable = true;
            extensions.fzf-native.enable = true;
          };

          neo-tree = {
            enable = true;
            settings = {
              window.width = 40;
              window.auto_expand_width = true;
              default_component_configs.container = {
                enable_character_fade = false;
              };
              default_component_configs.diagnostics.symbols = {
                error = "";
                warn = "";
                info = "";
                hint = "";
              };
              default_component_configs.modified.symbol = "*";
              filesystem = {
                follow_current_file = {
                  enabled = true;
                  leave_dirs_open = true;
                };
                group_empty_dirs = true;
                scan_mode = "deep";
                use_libuv_file_watcher = true;
                filtered_items = {
                  visible = true;
                  show_hidden_count = false;
                  hide_dotfiles = false;
                  hide_gitignored = false;
                  never_show = [ ".git" ];
                };
                window.mappings.O = "system_open";
              };
              commands.system_open.__raw = ''require("neru.tree").system_open'';
              renderers = {
                directory = [
                  { __unkeyed-1 = "indent"; }
                  { __unkeyed-1 = "icon"; }
                  { __unkeyed-1 = "current_filter"; }
                  {
                    __unkeyed-1 = "container";
                    content = [
                      {
                        __unkeyed-1 = "name";
                        zindex = 10;
                      }
                      {
                        __unkeyed-1 = "symlink_target";
                        zindex = 10;
                        highlight = "NeoTreeSymbolicLinkTarget";
                      }
                      {
                        __unkeyed-1 = "clipboard";
                        zindex = 10;
                      }
                      {
                        __unkeyed-1 = "diagnostics";
                        errors_only = true;
                        zindex = 20;
                        align = "right";
                        hide_when_expanded = true;
                      }
                      {
                        __unkeyed-1 = "file_size";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "type";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "last_modified";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "created";
                        zindex = 10;
                        align = "right";
                      }
                    ];
                  }
                ];
                file = [
                  { __unkeyed-1 = "indent"; }
                  { __unkeyed-1 = "icon"; }
                  {
                    __unkeyed-1 = "container";
                    content = [
                      {
                        __unkeyed-1 = "name";
                        zindex = 10;
                      }
                      {
                        __unkeyed-1 = "symlink_target";
                        zindex = 10;
                        highlight = "NeoTreeSymbolicLinkTarget";
                      }
                      {
                        __unkeyed-1 = "clipboard";
                        zindex = 10;
                      }
                      {
                        __unkeyed-1 = "bufnr";
                        zindex = 10;
                      }
                      {
                        __unkeyed-1 = "modified";
                        zindex = 20;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "diagnostics";
                        zindex = 20;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "file_size";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "type";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "last_modified";
                        zindex = 10;
                        align = "right";
                      }
                      {
                        __unkeyed-1 = "created";
                        zindex = 10;
                        align = "right";
                      }
                    ];
                  }
                ];
              };
            };
          };

          gitsigns = {
            enable = true;
            settings = {
              signcolumn = false;
              current_line_blame = true;
              current_line_blame_opts = {
                virt_text = true;
                virt_text_pos = "eol";
                delay = 300;
              };
              current_line_blame_formatter = "  <author>, <author_time:%R> - <summary>";
            };
          };

          lualine = {
            enable = true;
            settings = {
              options = {
                globalstatus = true;
                section_separators = "";
                component_separators = "";
              };
              sections = {
                lualine_a = [ "mode" ];
                lualine_b = [
                  {
                    __unkeyed-1 = "branch";
                    icons_enabled = false;
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").diagnostics'';
                  }
                ];
                lualine_c.__raw = "{}";
                lualine_x = [
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").search'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").position'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").indent'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").encoding'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").eol'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").language'';
                  }
                  {
                    __unkeyed-1.__raw = ''require("neru.statusline").formatter'';
                  }
                ];
                lualine_y.__raw = "{}";
                lualine_z.__raw = "{}";
              };
              extensions = [ "neo-tree" ];
            };
          };

          highlight-colors = {
            enable = true;
            settings = {
              render = "background";
              enable_tailwind = true;
            };
          };

          trouble.enable = true;

          neogit.enable = true;
          diffview.enable = true;

          render-markdown = {
            enable = true;
            settings = {
              heading = {
                icons = [
                  "# "
                  "## "
                  "### "
                  "#### "
                  "##### "
                  "###### "
                ];
                backgrounds.__raw = "{}";
                sign = false;
              };
              code = {
                width = "block";
                left_pad = 2;
                right_pad = 2;
                inline_pad = 1;
              };
              html.tag =
                let
                  scoped =
                    hl: tags:
                    lib.genAttrs tags (_: {
                      scope_highlight = hl;
                    });
                in
                lib.genAttrs
                  [
                    "center"
                    "details"
                    "div"
                    "p"
                    "span"
                    "summary"
                    "table"
                    "tbody"
                    "td"
                    "thead"
                    "tr"
                  ]
                  (_: {
                    __raw = "{}";
                  })
                // scoped "@markup.strong" [
                  "b"
                  "strong"
                  "th"
                ]
                // scoped "@markup.italic" [
                  "em"
                  "i"
                ]
                // scoped "@markup.strikethrough" [
                  "del"
                  "s"
                  "strike"
                ]
                // scoped "@markup.underline" [
                  "ins"
                  "u"
                ]
                // scoped "RenderMarkdownCodeInline" [
                  "code"
                  "kbd"
                ]
                // builtins.listToAttrs (
                  map
                    (n: {
                      name = "h${n}";
                      value.scope_highlight = "RenderMarkdownH${n}";
                    })
                    [
                      "1"
                      "2"
                      "3"
                      "4"
                      "5"
                      "6"
                    ]
                )
                // {
                  a = {
                    icon = "󰌹 ";
                    highlight = "RenderMarkdownLink";
                    scope_highlight = "RenderMarkdownLink";
                  };
                };
              latex.converter = [ "latex2text" ];
              completions.blink.enabled = true;
            };
          };
          typst-preview.enable = true;
          vimtex = {
            enable = true;
            texlivePackage = null;
          };

          vim-be-good.enable = true;
        };

        keymaps = [
          {
            key = "<leader>ff";
            action = "<cmd>Telescope find_files<CR>";
            options.desc = "Find files";
          }
          {
            key = "<leader>fg";
            action = "<cmd>Telescope live_grep<CR>";
            options.desc = "Live grep";
          }
          {
            key = "<leader>fb";
            action = "<cmd>Telescope buffers<CR>";
            options.desc = "Buffers";
          }
          {
            key = "<leader>fr";
            action = "<cmd>Telescope oldfiles<CR>";
            options.desc = "Recent files";
          }
          {
            key = "<leader>fh";
            action = "<cmd>Telescope help_tags<CR>";
            options.desc = "Help tags";
          }
          {
            key = "<leader>e";
            action = "<cmd>Neotree toggle<CR>";
            options.desc = "Toggle file tree";
          }

          {
            key = "[d";
            action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true }) end";
            options.desc = "Previous diagnostic";
          }
          {
            key = "]d";
            action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true }) end";
            options.desc = "Next diagnostic";
          }
          {
            key = "<leader>cf";
            action.__raw = "function() require('conform').format({ lsp_format = 'fallback' }) end";
            options.desc = "Format buffer";
          }
          {
            key = "<leader>xx";
            action = "<cmd>Trouble diagnostics toggle<CR>";
            options.desc = "Workspace diagnostics";
          }
          {
            key = "<leader>xd";
            action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
            options.desc = "Document diagnostics";
          }

          {
            key = "<leader>gg";
            action = "<cmd>Neogit<CR>";
            options.desc = "Neogit";
          }
          {
            key = "<leader>gd";
            action = "<cmd>DiffviewOpen<CR>";
            options.desc = "Diff view";
          }
          {
            key = "<leader>gb";
            action = "<cmd>Gitsigns blame_line<CR>";
            options.desc = "Blame line";
          }
          {
            key = "[h";
            action = "<cmd>Gitsigns prev_hunk<CR>";
            options.desc = "Previous hunk";
          }
          {
            key = "]h";
            action = "<cmd>Gitsigns next_hunk<CR>";
            options.desc = "Next hunk";
          }
          {
            key = "<leader>hs";
            action = "<cmd>Gitsigns stage_hunk<CR>";
            options.desc = "Stage hunk";
          }
          {
            key = "<leader>hr";
            action = "<cmd>Gitsigns reset_hunk<CR>";
            options.desc = "Reset hunk";
          }
          {
            key = "<leader>hp";
            action = "<cmd>Gitsigns preview_hunk<CR>";
            options.desc = "Preview hunk";
          }

          {
            key = "<leader>tp";
            action = "<cmd>TypstPreviewToggle<CR>";
            options.desc = "Typst preview";
          }

          {
            key = "<A-j>";
            action = "<cmd>m .+1<CR>==";
            options.desc = "Move line down";
          }
          {
            key = "<A-k>";
            action = "<cmd>m .-2<CR>==";
            options.desc = "Move line up";
          }
          {
            mode = "v";
            key = "<A-j>";
            action = ":m '>+1<CR>gv=gv";
            options = {
              desc = "Move selection down";
              silent = true;
            };
          }
          {
            mode = "v";
            key = "<A-k>";
            action = ":m '<-2<CR>gv=gv";
            options = {
              desc = "Move selection up";
              silent = true;
            };
          }

          {
            mode = [
              "n"
              "v"
            ];
            key = "<Up>";
            action = "<Nop>";
            options.desc = "Disabled arrow key";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<Down>";
            action = "<Nop>";
            options.desc = "Disabled arrow key";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<Left>";
            action = "<Nop>";
            options.desc = "Disabled arrow key";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<Right>";
            action = "<Nop>";
            options.desc = "Disabled arrow key";
          }
          {
            key = "<S-h>";
            action = "<cmd>bprevious<CR>";
            options.desc = "Previous buffer";
          }
          {
            key = "<S-l>";
            action = "<cmd>bnext<CR>";
            options.desc = "Next buffer";
          }
          {
            key = "<leader>bd";
            action.__raw = ''require("neru.buffers").close'';
            options.desc = "Close buffer";
          }
          {
            key = "<leader>v";
            action.__raw = ''require("neru.buffers").split'';
            options.desc = "Move buffer into right split";
          }
          {
            key = "<C-h>";
            action = "<C-w>h";
            options.desc = "Window left";
          }
          {
            key = "<C-j>";
            action = "<C-w>j";
            options.desc = "Window down";
          }
          {
            key = "<C-k>";
            action = "<C-w>k";
            options.desc = "Window up";
          }
          {
            key = "<C-l>";
            action = "<C-w>l";
            options.desc = "Window right";
          }

          {
            key = "<leader>w";
            action = "<cmd>write<CR>";
            options.desc = "Save";
          }
          {
            mode = "n";
            key = "<Esc>";
            action = "<cmd>nohlsearch<CR>";
            options.desc = "Clear search highlight";
          }
        ];
      };

      xdg.desktopEntries.nvim-kitty = {
        name = "Neovim";
        exec = "kitty -e nvim %F";
        icon = "nvim";
        terminal = false;
        noDisplay = true;
        mimeType = textTypes;
      };

      xdg.mimeApps.defaultApplications = lib.genAttrs textTypes (_: [
        "nvim-kitty.desktop"
        "micro.desktop"
      ]);

      theme-engine.apps.nvim = {
        target = "~/.local/share/theme-engine/nvim.lua";
        template = builtins.readFile ./theme.lua.tmpl;
      };
    };
}
