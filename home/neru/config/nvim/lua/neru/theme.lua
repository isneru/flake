local c = require("neru.colors")

require("base16-colorscheme").setup({
	base00 = c.bg,
	base01 = c.bgAlt,
	base02 = c.border,
	base03 = c.fgMuted,
	base04 = c.fgDim,
	base05 = c.fg,
	base06 = c.fg,
	base07 = c.fg,
	base08 = c.red,
	base09 = c.orange,
	base0A = c.warning,
	base0B = c.success,
	base0C = c.cyan,
	base0D = c.blue,
	base0E = c.purple,
	base0F = c.red,
})

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = c.bgAlt })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "NONE" })
vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE" })
vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE" })
vim.api.nvim_set_hl(0, "@punctuation.special.markdown", { bg = "NONE" })
