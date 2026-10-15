local M = {}

local function configured()
	local ok, nt = pcall(require, "neo-tree")
	local w = ok and nt.config and nt.config.window and nt.config.window.width
	return type(w) == "number" and w or nil
end

local function restore()
	local wins = vim.api.nvim_tabpage_list_wins(0)
	if #wins < 2 then
		return
	end
	local want = configured()
	if not want then
		return
	end
	for _, win in ipairs(wins) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == "neo-tree" and vim.api.nvim_win_get_width(win) >= vim.o.columns - 10 then
				pcall(vim.api.nvim_win_set_width, win, want)
			end
		end
	end
end

function M.system_open(state)
	local _, err = vim.ui.open(state.tree:get_node():get_id())
	if err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "BufWinEnter" }, {
		group = vim.api.nvim_create_augroup("NeruTree", { clear = true }),
		callback = vim.schedule_wrap(restore),
	})
end

return M
