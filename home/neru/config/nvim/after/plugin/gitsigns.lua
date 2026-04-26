local function clear_bg()
	local groups = {
		"GitSignsAdd", "GitSignsChange", "GitSignsDelete",
		"GitSignsTopdelete", "GitSignsChangedelete", "GitSignsUntracked",
		"GitSignsAddNr", "GitSignsChangeNr", "GitSignsDeleteNr",
		"GitSignsAddLn", "GitSignsChangeLn", "GitSignsDeleteLn",
	}
	for _, group in ipairs(groups) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
		if ok then
			hl.bg = nil
			vim.api.nvim_set_hl(0, group, hl)
		end
	end
end

require("gitsigns").setup({
	current_line_blame = true,
	current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = "eol",
		delay = 100,
		ignore_whitespace = false,
	},
	current_line_blame_formatter = "<author>, <author_time:%d-%m-%Y> - <summary>",
	on_attach = function(bufnr)
		clear_bg()
	end,
})
