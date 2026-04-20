require("mini.pairs").setup()

require("mini.notify").setup({
	window = {
		config = { border = "rounded" },
		winblend = 0,
		lsp_progress = {
			enable = true,
		},
	},
})

-- Custom notify logic to filter out LSP/Formatter spam
local default_notify = require("mini.notify").make_notify()
local silenced_messages = {
	"Diagnosing",
	"Formatting",
	"code_action",
	"No information available",
}

vim.notify = function(msg, level, opts)
	if not msg then
		return
	end
	for _, phrase in ipairs(silenced_messages) do
		if string.find(msg, phrase) then
			return -- Silently drop the notification
		end
	end
	default_notify(msg, level, opts)
end

vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft == "" or vim.bo[args.buf].buftype ~= "" then
			return
		end

		local fn = vim.fn.fnamemodify(args.file, ":t")
		vim.notify("Saved " .. fn, vim.log.levels.INFO, { title = "File Written" })
	end,
})

require("mini.move").setup({
	mappings = {
		left = "<M-h>",
		right = "<M-l>",
		down = "<M-j>",
		up = "<M-k>",
		line_left = "<M-h>",
		line_right = "<M-l>",
		line_down = "<M-j>",
		line_up = "<M-k>",
	},
	options = {
		reindent_linewise = true,
	},
})

require("mini.comment").setup({
	options = {
		custom_commentstring = nil,
		ignore_blank_line = false,
		start_of_line = false,
		pad_comment_parts = true,
	},
	mappings = {
		comment = "gc",
		comment_line = "gcc",
	},
})

require("mini.surround").setup({
	mappings = {
		add = "S", -- Add surrounding in Normal and Visual modes
		delete = "ds", -- Delete surrounding
		find = "sf", -- Find surrounding (to the right)
		find_left = "sF", -- Find surrounding (to the left)
		highlight = "sh", -- Highlight surrounding
		replace = "cs", -- Replace surrounding
	},
})

vim.keymap.set("n", "<leader>?", function()
	require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
