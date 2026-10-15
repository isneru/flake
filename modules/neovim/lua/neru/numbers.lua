local M = {}

local function set(on)
	return function()
		if vim.wo.number then
			vim.wo.relativenumber = on
		end
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("NeruNumbers", { clear = true })
	vim.api.nvim_create_autocmd("InsertEnter", { group = group, callback = set(false) })
	vim.api.nvim_create_autocmd("InsertLeave", { group = group, callback = set(true) })
end

return M
