local M = {}

local DATA_FILE = vim.fn.expand("~/.local/share/theme-engine/nvim-theme.lua")

local function color_overrides()
	local ok, data = pcall(dofile, DATA_FILE)
	if ok and data and data.colors then
		return data.colors
	end
	return {}
end

function M.apply()
	require("catppuccin").setup({
		flavour = "mocha",
		transparent_background = true,
		color_overrides = { mocha = color_overrides() },
		integrations = {
			cmp = true,
			dashboard = true,
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
end

M.apply()

local reload_signal = vim.uv.new_signal()
reload_signal:start("sigusr1", vim.schedule_wrap(M.apply))

return M
