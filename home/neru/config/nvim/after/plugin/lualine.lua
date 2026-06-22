require("lualine").setup({
	options = {
		icons_enabled = false,
		theme = "catppuccin",
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
