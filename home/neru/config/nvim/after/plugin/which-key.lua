local whichkey = require("which-key")

whichkey.setup({
	preset = "helix",

})

vim.keymap.set("n", "<leader>?", function()
	whichkey.show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })
