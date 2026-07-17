vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap

-- Clear search highlights when you press <Leader> + nh
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })

-- Close the current file (buffer) without closing Neovim
-- (Unless it's the last file open)
keymap.set("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close current file" })

-- Optional: A quick way to see a list of all your open buffers at the bottom of the screen
keymap.set("n", "<leader>bl", "<cmd>ls<CR>:b ", { desc = "List buffers and prompt to switch" })

keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })

keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left split" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to lower split" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to upper split" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right split" })

keymap.set("n", "<leader>sv", "<cmd>vsp<cr>", { desc = "Split vertically" })
keymap.set("n", "<leader>ss", "<cmd>sp<cr>", { desc = "Split horizontally" })
keymap.set("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close split" })

keymap.set("t", "<C-q>", "<C-\\><C-n><cmd>close<cr>", { desc = "Close terminal split" })

keymap.set("n", "<leader>stv", function()
	vim.cmd("rightbelow vsp | term")
	vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.3))
	vim.schedule(function()
		vim.cmd("startinsert")
	end)
end, { desc = "Terminal in vertical split (30%)" })
keymap.set("n", "<leader>sts", function()
	vim.cmd("botright sp | term")
	vim.cmd("resize " .. math.floor(vim.o.lines * 0.25))
	vim.schedule(function()
		vim.cmd("startinsert")
	end)
end, { desc = "Terminal in horizontal split (25%)" })

vim.keymap.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
vim.keymap.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
