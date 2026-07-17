require("treesj").setup({ use_default_keymaps = false })

vim.keymap.set("n", "gS", function()
	require("treesj").toggle()
end, { desc = "Split/join toggle" })
