local c = require("neru.colors")

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
