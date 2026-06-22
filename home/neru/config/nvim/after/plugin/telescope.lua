local telescope = require("telescope")
local builtin = require("telescope.builtin")

telescope.load_extension("fzf")

telescope.setup({
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

vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fl", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fr", builtin.lsp_references, { desc = "LSP references" })
vim.keymap.set("n", "gd", builtin.lsp_definitions, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>ft", builtin.lsp_type_definitions, { desc = "LSP type definitions" })
vim.keymap.set("n", "<leader>fi", builtin.lsp_implementations, { desc = "LSP implementations" })
vim.keymap.set("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "LSP document symbols" })
