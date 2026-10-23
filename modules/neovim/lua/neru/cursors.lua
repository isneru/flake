local M = {}

function M.setup()
	local mc = require("multicursor-nvim")
	local set = vim.keymap.set

	set({ "n", "x" }, "<leader>a", mc.matchAllAddCursors, { desc = "Cursor on every match" })
	set({ "n", "x" }, "<C-n>", function()
		mc.matchAddCursor(1)
	end, { desc = "Cursor on next match" })
	set("n", "<C-A-j>", function()
		mc.lineAddCursor(1)
	end, { desc = "Cursor below" })
	set("n", "<C-A-k>", function()
		mc.lineAddCursor(-1)
	end, { desc = "Cursor above" })
	set("x", "I", mc.insertVisual, { desc = "Insert on every line" })
	set("x", "A", mc.appendVisual, { desc = "Append on every line" })
	set("n", "<A-LeftMouse>", mc.handleMouse, { desc = "Toggle cursor" })
	set("n", "<A-LeftDrag>", mc.handleMouseDrag)
	set("n", "<A-LeftRelease>", mc.handleMouseRelease)

	mc.addKeymapLayer(function(layerSet)
		layerSet({ "n", "x" }, "<C-x>", function()
			mc.matchSkipCursor(1)
		end, { desc = "Skip match" })
		layerSet({ "n", "x" }, "<C-p>", mc.deleteCursor, { desc = "Remove cursor" })
		layerSet("n", "<Esc>", function()
			if not mc.cursorsEnabled() then
				mc.enableCursors()
			else
				mc.clearCursors()
			end
		end, { desc = "Back to one cursor" })
	end)
end

return M
