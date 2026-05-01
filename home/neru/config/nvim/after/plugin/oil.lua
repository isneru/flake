require("oil").setup({
	default_file_explorer = true,
	delete_to_trash = true,
	view_options = {
		show_hidden = true,
	},
	float = {
		padding = 4,
		max_width = 80,
		max_height = 30,
	},
})

vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open file explorer (parent dir)" })
vim.keymap.set("n", "<leader>o", "<cmd>Oil .<cr>", { desc = "Open file explorer (cwd)" })
vim.keymap.set("n", "<leader>O", function()
	vim.cmd("vsplit")
	require("oil").open(vim.fn.getcwd())
end, { desc = "Open file explorer split (cwd)" })
