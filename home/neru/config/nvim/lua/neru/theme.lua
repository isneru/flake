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
	base08 = c.magenta,
	base09 = c.orange,
	base0A = c.red,
	base0B = c.cyan,
	base0C = c.red,
	base0D = c.purple,
	base0E = c.blue,
	base0F = c.magenta,
})

vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "NONE" })
vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE" })
vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "NONE" })
vim.api.nvim_set_hl(0, "@punctuation.special.markdown", { bg = "NONE" })
