vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap

-- Clear search highlights when you press <Leader> + nh
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- Use Tab and Shift-Tab to cycle through your open files (buffers)
keymap.set("n", "<TAB>", "<cmd>bnext<CR>", { desc = "Next open file" })
keymap.set("n", "<S-TAB>", "<cmd>bprevious<CR>", { desc = "Previous open file" })

-- Close the current file (buffer) without closing Neovim
-- (Unless it's the last file open)
keymap.set("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close current file" })

-- Optional: A quick way to see a list of all your open buffers at the bottom of the screen
keymap.set("n", "<leader>bl", "<cmd>ls<CR>:b ", { desc = "List buffers and prompt to switch" })