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
