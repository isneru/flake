vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function(event)
		local opts = { buffer = event.buf, silent = true }

		-- open today's daily note
		vim.keymap.set("n", "<leader>nd", function()
			local path = vim.fn.expand("~/vault/00 - Daily/") .. os.date("%d-%m-%Y") .. ".md"
			vim.cmd("e " .. vim.fn.fnameescape(path))
		end, vim.tbl_extend("force", opts, { desc = "Open today's note" }))

		-- backlinks for the current note
		vim.keymap.set(
			"n",
			"<leader>nb",
			vim.lsp.buf.references,
			vim.tbl_extend("force", opts, { desc = "Note backlinks" })
		)

		-- follow wikilink under cursor
		vim.keymap.set(
			"n",
			"<leader>nf",
			vim.lsp.buf.definition,
			vim.tbl_extend("force", opts, { desc = "Follow wikilink" })
		)
	end,
})
