require("catppuccin").setup({
	flavour = "mocha",
	transparent_background = true,
	integrations = {
		cmp = true,
		harpoon = true,
		lualine = {},
		mini = { enabled = true },
		native_lsp = {
			enabled = true,
			underlines = {
				errors = { "undercurl" },
				hints = { "underdotted" },
				warnings = { "undercurl" },
				information = { "underdotted" },
			},
		},
		oil = true,
		telescope = { enabled = true },
		treesitter = true,
		which_key = true,
	},
})

vim.cmd.colorscheme("catppuccin")
