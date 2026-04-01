local colors_file = vim.fn.expand("~/.config/noctalia/colors.json")
local theme_colors = {
    -- Fallback colors just in case the file can't be read
    mPrimary = "#7ed0ff",
    mTertiary = "#cbc1e9",
    mError = "#ffb4ab",
    mSurface = "#111416",
    mOnSurface = "#e1e2e5",
    mSurfaceVariant = "#1d2022",
    mOnSurfaceVariant = "#c1c7cd",
}

if vim.fn.filereadable(colors_file) == 1 then
    local f = io.open(colors_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, parsed = pcall(vim.fn.json_decode, content)
        if ok and type(parsed) == "table" then
            for k, v in pairs(parsed) do
                theme_colors[k] = v
            end
        end
    end
end

require("gitsigns").setup({
    current_line_blame = true,
    current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 100,
        ignore_whitespace = false,
    },
    current_line_blame_formatter = "<author>, <author_time:%d-%m-%Y> - <summary>",
})

require("lualine").setup({
    options = {
        icons_enabled = false,
        theme = {
            normal = {
                a = { fg = theme_colors.mSurface, bg = theme_colors.mPrimary, gui = "bold" },
                b = { fg = theme_colors.mOnSurface, bg = theme_colors.mSurfaceVariant },
                c = { fg = theme_colors.mOnSurfaceVariant, bg = "none" }, -- Transparent middle
            },
            insert = {
                a = { fg = theme_colors.mSurface, bg = theme_colors.mTertiary, gui = "bold" },
                b = { fg = theme_colors.mOnSurface, bg = theme_colors.mSurfaceVariant },
                c = { fg = theme_colors.mOnSurfaceVariant, bg = "none" },
            },
            visual = {
                a = { fg = theme_colors.mSurface, bg = theme_colors.mError, gui = "bold" },
                b = { fg = theme_colors.mOnSurface, bg = theme_colors.mSurfaceVariant },
                c = { fg = theme_colors.mOnSurfaceVariant, bg = "none" },
            },
            inactive = {
                a = { fg = theme_colors.mOnSurfaceVariant, bg = "none", gui = "bold" },
                b = { fg = theme_colors.mOnSurfaceVariant, bg = "none" },
                c = { fg = theme_colors.mOnSurfaceVariant, bg = "none" },
            },
        },
        globalstatus = true,
        component_separators = "|",
        section_separators = "",
        disabled_filetypes = {
            statusline = { "NvimTree" },
            winbar = { "NvimTree" },
        },
    },
    sections = {
        lualine_a = {
            {
                "mode",
                fmt = function(str)
                    return str:sub(1, 1)
                end,
            },
        },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
    },
    tabline = {},
    extensions = {},
})
vim.opt.showmode = false
vim.o.cmdheight = 0
vim.o.laststatus = 3
vim.opt.completeopt = { "menu", "menuone", "noselect" }

require("telescope").setup({
    defaults = {
        initial_mode = "insert",
        selection_strategy = "reset",
        sorting_strategy = "ascending",
        layout_strategy = "horizontal",
        layout_config = {
            horizontal = {
                prompt_position = "top",
                preview_width = 0.55,
                results_width = 0.8,
            },
            vertical = {
                mirror = false,
            },
            width = 0.87,
            height = 0.80,
            preview_cutoff = 120,
        },
        file_ignore_patterns = { "bun.lock" },
    },
    pickers = {
        find_files = {
            hidden = true,
        },
    },
    extensions = {
        fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
        },
    },
})

require("telescope").load_extension("fzf")
require("telescope").load_extension("file_browser")

local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap("n", "<leader>ff", "<cmd>lua require('telescope.builtin').find_files()<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>fg", "<cmd>lua require('telescope.builtin').live_grep()<CR>", opts)
vim.api.nvim_set_keymap(
    "n",
    "<leader>fl",
    "<cmd>lua require('telescope.builtin').current_buffer_fuzzy_find()<CR>",
    opts
)
vim.api.nvim_set_keymap("n", "<leader>fr", "<cmd>lua require('telescope.builtin').lsp_references()<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>fd", "<cmd>lua require('telescope.builtin').lsp_definitions()<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>ft", "<cmd>lua require('telescope.builtin').lsp_type_definitions()<CR>", opts)
vim.api.nvim_set_keymap("n", "<leader>fi", "<cmd>Telescope lsp_implementations<CR>", opts)
vim.api.nvim_set_keymap("n", "<C-j>", "<cmd>Telescope lsp_document_symbols<CR>", opts)

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
    renderer = {
        icons = {
            show = {
                file = false,
                folder = false,
                folder_arrow = true,
                git = false,
                modified = true,
            },
        },
    },
    view = {
        width = 30,
        side = "right",
    },
    disable_netrw = true,
    hijack_netrw = true,
    update_focused_file = { enable = true },
    filters = { dotfiles = false, git_ignored = false },
    git = { enable = true },
    actions = {
        open_file = {
            quit_on_open = true,
        },
    },
})

vim.keymap.set("n", "<C-b>", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
vim.keymap.set("n", "<leader>e", ":NvimTreeFocus<CR>", { desc = "Focus file explorer" })

vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
vim.api.nvim_set_hl(0, "FloatTitle", { bg = "none" })
vim.api.nvim_set_hl(0, "StatusLine", { bg = "none" })
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "none" })
