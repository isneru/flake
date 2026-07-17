require("render-markdown").setup({
	render_modes = { "n", "c" },
	anti_conceal = { enabled = true },
	heading = { width = "block" },
	code = { width = "block" },
})

vim.keymap.set("n", "<leader>mp", "<cmd>RenderMarkdown toggle<cr>", { desc = "Markdown render toggle" })
