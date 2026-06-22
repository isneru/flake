require("nvim-treesitter").setup({
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
		if vim.bo.buftype == "" and pcall(vim.treesitter.start) then
			vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

require("nvim-treesitter-textobjects").setup({
	select = { lookahead = true },
	move = { set_jumps = true },
})

local select = require("nvim-treesitter-textobjects.select")
local move = require("nvim-treesitter-textobjects.move")
local swap = require("nvim-treesitter-textobjects.swap")

-- text objects
local sel = {
	{ "af", "@function.outer", "outer function" },
	{ "if", "@function.inner", "inner function" },
	{ "ac", "@class.outer", "outer class" },
	{ "ic", "@class.inner", "inner class" },
	{ "aa", "@parameter.outer", "outer argument" },
	{ "ia", "@parameter.inner", "inner argument" },
	{ "ai", "@conditional.outer", "outer conditional" },
	{ "ii", "@conditional.inner", "inner conditional" },
}
for _, v in ipairs(sel) do
	vim.keymap.set({ "x", "o" }, v[1], function()
		select.select_textobject(v[2], "textobjects")
	end, { desc = v[3] })
end

-- move
vim.keymap.set("n", "]f", function()
	move.goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
vim.keymap.set("n", "]F", function()
	move.goto_next_end("@function.outer", "textobjects")
end, { desc = "Next function end" })
vim.keymap.set("n", "[f", function()
	move.goto_previous_start("@function.outer", "textobjects")
end, { desc = "Prev function start" })
vim.keymap.set("n", "[F", function()
	move.goto_previous_end("@function.outer", "textobjects")
end, { desc = "Prev function end" })

-- swap arguments
vim.keymap.set("n", "<M-.>", function()
	swap.swap_next("@parameter.inner", "textobjects")
end, { desc = "Swap with next argument" })
vim.keymap.set("n", "<M-,>", function()
	swap.swap_previous("@parameter.inner", "textobjects")
end, { desc = "Swap with prev argument" })
