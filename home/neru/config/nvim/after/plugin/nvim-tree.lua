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
