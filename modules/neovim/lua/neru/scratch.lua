local M = {}

local function claim()
	local buf = vim.api.nvim_get_current_buf()
	local bo = vim.bo[buf]
	if bo.buftype ~= "" or not bo.buflisted or bo.modified or vim.api.nvim_buf_get_name(buf) ~= "" then
		return
	end
	if vim.api.nvim_buf_line_count(buf) > 1 or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= "" then
		return
	end
	bo.buftype = "nofile"
	bo.bufhidden = "hide"
	bo.swapfile = false
	vim.b[buf].scratch = true
end

local function telescope()
	local ok, make_entry = pcall(require, "telescope.make_entry")
	if not ok then
		return
	end
	local gen = make_entry.gen_from_buffer
	make_entry.gen_from_buffer = function(opts)
		local maker = gen(opts)
		return function(e)
			local entry = maker(e)
			if entry and vim.b[entry.bufnr].scratch then
				entry.value = "scratch"
				entry.filename = "scratch"
				entry.ordinal = entry.bufnr .. " : scratch"
			end
			return entry
		end
	end
end

function M.setup()
	telescope()
	vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
		group = vim.api.nvim_create_augroup("neru.scratch", {}),
		callback = claim,
	})
end

return M
