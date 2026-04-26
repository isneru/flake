local telescope = require("telescope")

telescope.load_extension("fzf")
telescope.load_extension("file_browser")

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
