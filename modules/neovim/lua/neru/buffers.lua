local M = {}

local function listed(buf, current)
	return buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
end

function M.close()
	local cur = vim.api.nvim_get_current_buf()
	if vim.bo[cur].buftype ~= "" or not vim.bo[cur].buflisted then
		return
	end
	local alt = vim.fn.bufnr("#")
	local target = listed(alt, cur) and alt or nil
	if not target then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if listed(buf, cur) then
				target = buf
				break
			end
		end
	end
	target = target or vim.api.nvim_create_buf(true, false)
	for _, win in ipairs(vim.fn.win_findbuf(cur)) do
		vim.api.nvim_win_set_buf(win, target)
	end
	pcall(vim.api.nvim_buf_delete, cur, {})
end

local function file(buf, current)
	return listed(buf, current) and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function previous(cur)
	local alt = vim.fn.bufnr("#")
	if file(alt, cur) then
		return alt
	end
	local best
	for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if file(info.bufnr, cur) and (not best or info.lastused > best.lastused) then
			best = info
		end
	end
	return best and best.bufnr
end

function M.split()
	local cur = vim.api.nvim_get_current_buf()
	if vim.bo[cur].buftype ~= "" then
		return
	end
	local win = vim.api.nvim_get_current_win()
	local prev = previous(cur)
	vim.cmd("vsplit")
	if prev then
		vim.api.nvim_win_set_buf(win, prev)
	end
end

return M
