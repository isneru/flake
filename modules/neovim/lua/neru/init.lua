local M = {}

function M.setup()
	require("neru.ui").setup()
	require("neru.tree").setup()
	require("neru.lsp").setup()
	require("neru.numbers").setup()
	require("neru.colors").setup()
	require("neru.bar").setup()
	require("neru.scratch").setup()
	require("neru.read").setup()
	require("neru.cursors").setup()
	require("neru.align").setup()
end

return M
