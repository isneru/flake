local conform = require("conform")

conform.setup({
	formatters_by_ft = {
		-- keep-sorted start block=yes
		astro = { "prettierd", "prettier", stop_after_first = true },
		css = { "prettierd", "prettier", stop_after_first = true },
		javascript = { "prettierd", "prettier", stop_after_first = true },
		javascriptreact = { "prettierd", "prettier", stop_after_first = true },
		lua = { "keep-sorted", "stylua" },
		nix = { "keep-sorted", "nixfmt" },
		typescript = { "prettierd", "prettier", stop_after_first = true },
		vue = { "prettierd", "prettier", stop_after_first = true },
		-- keep-sorted end
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_format = "fallback",
	},
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	conform.format({ timeout_ms = 500, lsp_format = "fallback" })
end, { desc = "Format buffer or selection" })
