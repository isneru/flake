require("mini.notify").setup({
	window = {
		config = { border = "rounded" },
		winblend = 0,
		lsp_progress = {
			enable = true,
		},
	},
})
local c = require("neru.colors")
vim.api.nvim_set_hl(0, "MiniNotifyNormal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "MiniNotifyBorder", { bg = "NONE", fg = c.border })
vim.api.nvim_set_hl(0, "MiniNotifyTitle", { bg = "NONE" })

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
