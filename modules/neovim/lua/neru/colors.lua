local M = {}

local dir = vim.fn.expand("~/.local/share/theme-engine")

local function apply()
	pcall(dofile, dir .. "/nvim.lua")
end

function M.setup()
	apply()
	local watcher = vim.uv.new_fs_event()
	if watcher then
		watcher:start(
			dir,
			{},
			vim.schedule_wrap(function(_, name)
				if name == "nvim.lua" then
					apply()
				end
			end)
		)
	end
end

return M
