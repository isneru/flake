require("flash").setup({
	prompt = { enabled = false },
})

vim.keymap.set({ "n", "x", "o" }, "zk", function()
	require("flash").jump()
end, { desc = "Flash: jump" })

vim.keymap.set({ "n", "x", "o" }, "zK", function()
	require("flash").jump({ search = { mode = "search", max_length = false } })
end, { desc = "Flash: search whole buffer" })
