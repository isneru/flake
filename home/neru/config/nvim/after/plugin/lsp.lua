local cmp = require("cmp")

cmp.setup({
    formatting = {
        format = function(entry, vim_item)
            -- source
            vim_item.menu = ({
                buffer = "[buffer]",
                nvim_lsp = "[lsp]",
                luasnip = "[luasnip]",
                nvim_lua = "[lua]",
            })[entry.source.name]
            return vim_item
        end,
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = {
            border = "rounded",
            winhighlight = "normal:normal,floatborder:floatborder,cursorline:visual,search:none",
            max_width = 80,
            max_height = 20,
        },
    },
    mapping = {
        ["<c-b>"] = cmp.mapping.scroll_docs(-4),
        ["<c-f>"] = cmp.mapping.scroll_docs(4),
        ["<c-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
        ["<c-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),

        ["<tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.confirm({ select = true })
            else
                fallback()
            end
        end, { "i", "s" }),
    },

    sources = cmp.config.sources({
        {
            name = "nvim_lsp",
            ---@param entry cmp.entry
            ---@param ctx cmp.context
            entry_filter = function(entry, ctx)
                if ctx.filetype ~= "vue" then
                    return true
                end

                local cursor_before_line = ctx.cursor_before_line
                if cursor_before_line:sub(-1) == "@" then
                    return entry.completion_item.label:match("^@")
                elseif cursor_before_line:sub(-1) == ":" then
                    return entry.completion_item.label:match("^:") and not entry.completion_item.label:match("^:on%-")
                else
                    return true
                end
            end,
        },
        { name = "buffer" },
        { name = "path" },
        { name = "luasnip" },
        { name = "nvim_lua" },
    }),
    experimental = {
        ghost_text = false,
    },
})

cmp.event:on("menu_closed", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.b[bufnr]._vue_ts_cached_is_in_start_tag = nil
end)

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end,
})

local lsp_present, lspconfig = pcall(require, "lspconfig")

if not lsp_present then
    vim.notify("lspconfig not present", vim.log.levels.ERROR)
    return
end

vim.lsp.config("*", {
    root_markers = { ".git" },
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            },
        },
    },
})

local servers = {
    -- keep-sorted start block=yes newline_separated=yes
    astro = {
        settings = {
            typescript = {
                tsdk = vim.fn.expand("~") .. "/.npm-global/lib/node_modules/typescript/lib",
            },
        },
    },

    emmet_language_server = {
        filetypes = {
            "vue",
            "astro",
            "css",
            "html",
            "javascript",
            "javascriptreact",
            "typescriptreact",
        },
    },

    jsonls = {
        settings = {
            json = {
                validate = { enable = true },
                schemas = {
                    {
                        fileMatch = { "package.json" },
                        url = "https://www.schemastore.org/package.json",
                    },
                    {
                        fileMatch = { "tsconfig*.json" },
                        url = "https://www.schemastore.org/tsconfig.json",
                    },
                },
            },
        },
    },

    just = {},

    lua_ls = {
        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                },
                diagnostics = {
                    globals = { "vim" },
                },
                hint = { enable = true },
            },
        },
    },

    nil_ls = {},

    nixd = {},

    rust_analyzer = {},

    tailwindcss = {
        filetypes = {
            "vue",
            "astro",
            "javascriptreact",
            "typescriptreact",
            "html",
            "css",
        },
    },

    vtsls = {},

    yamlls = {
        settings = {
            yaml = {
                completion = true,
                validate = true,
                suggest = {
                    parentSkeletonSelectedFirst = true,
                },
                schemas = {
                    ["https://www.schemastore.org/github-workflow.json"] = ".github/workflows/*",
                    ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] =
                    "docker-compose*.{yml,yaml}",
                },
            },
            redhat = {
                telemetry = {
                    enable = false,
                },
            },
        },
    },
    taplo = {},
    clangd = {},
    jdtls = {},
    -- keep-sorted end
}
for server, config in pairs(servers) do
    vim.lsp.config(server, config)
    vim.lsp.enable(server)
end

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "if_many",
        header = "",
        prefix = "",
    },
})

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
    max_width = 80,
})

vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { noremap = true, silent = true, desc = "LSP Hover Documentation" })

require("nvim-treesitter").setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
    highlight = {
        enable = true,
    },
    indent = {
        enable = true,
    },
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function()
        if vim.bo.buftype == "" then
            vim.treesitter.start()
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
    end,
})
