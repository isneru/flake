local M = {}

function M.setup()
	require("neru.ui").setup()
	require("neru.tree").setup()
	require("neru.lsp").setup()
	require("neru.numbers").setup()
	require("neru.colors").setup()
end

return M
