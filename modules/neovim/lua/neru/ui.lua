local M = {}

function M.setup()
	pcall(function()
		require("vim._core.ui2").enable({})
	end)
end

return M
