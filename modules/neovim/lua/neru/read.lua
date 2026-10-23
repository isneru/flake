local M = {}

local function source(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	if path ~= "" and not vim.bo[buf].modified then
		return path
	end
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local copy = dir .. "/" .. (path ~= "" and vim.fs.basename(path) or "scratch.md")
	vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), copy)
	return copy
end

local function kitty(args, after)
	vim.system(vim.list_extend({ "kitty", "@" }, args), {}, function(done)
		if done.code ~= 0 then
			vim.schedule(function()
				vim.notify(vim.trim(done.stderr), vim.log.levels.ERROR)
			end)
		elseif after then
			after()
		end
	end)
end

local function open(vsplit)
	return function()
		if not vim.env.KITTY_LISTEN_ON then
			vim.notify("md-read needs kitty remote control", vim.log.levels.WARN)
			return
		end
		local path = vim.api.nvim_buf_get_name(0)
		if not vsplit then
			kitty({ "launch", "--type=overlay", "md-read", source(0) })
			return
		end
		path = path ~= "" and path or source(0)
		kitty({ "goto-layout", "splits" }, function()
			kitty({ "launch", "--location=vsplit", "md-read", path })
		end)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("NeruRead", { clear = true }),
		pattern = "markdown",
		callback = function(ev)
			vim.keymap.set("n", "<leader>mo", open(false), { buffer = ev.buf, desc = "Reading mode (overlay)" })
			vim.keymap.set("n", "<leader>mv", open(true), { buffer = ev.buf, desc = "Reading mode (vsplit)" })
		end,
	})
end

return M
