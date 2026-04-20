local c = require("neru.colors")

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
				a = { fg = c.bg, bg = c.info, gui = "bold" },
				b = { fg = c.fg, bg = c.bgAlt },
				c = { fg = c.fgMuted, bg = "none" },
			},
			insert = {
				a = { fg = c.bg, bg = c.accent, gui = "bold" },
				b = { fg = c.fg, bg = c.bgAlt },
				c = { fg = c.fgMuted, bg = "none" },
			},
			visual = {
				a = { fg = c.bg, bg = c.error, gui = "bold" },
				b = { fg = c.fg, bg = c.bgAlt },
				c = { fg = c.fgMuted, bg = "none" },
			},
			inactive = {
				a = { fg = c.fgMuted, bg = "none", gui = "bold" },
				b = { fg = c.fgMuted, bg = "none" },
				c = { fg = c.fgMuted, bg = "none" },
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
		side = "left",
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
