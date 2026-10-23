local M = {}

require("vim.lsp.inlay_hint")

local api = vim.api
local ns = api.nvim_create_namespace("neru.align")
local enabled = true
local reach = 200
local outlier = 30

local function operator(line)
	local i, quote = 1, nil
	while true do
		local at = line:find(quote and ("[\\" .. quote .. "]") or "[\"'`=({]", i)
		if not at then
			return nil
		end
		local c = line:sub(at, at)
		if quote then
			if c == "\\" then
				i = at + 2
			else
				quote, i = nil, at + 1
			end
		elseif c == "(" or c == "{" then
			return nil
		elseif c ~= "=" then
			quote, i = c, at + 1
		else
			local prev, nxt = line:sub(at - 1, at - 1), line:sub(at + 1, at + 1)
			if nxt == "=" or nxt == ">" or prev == "!" or prev == "~" then
				return nil
			end
			if (prev == "<" or prev == ">") and line:sub(at - 2, at - 2) ~= prev then
				return nil
			end
			local start = at
			while start > 1 and line:sub(start - 1, start - 1):find("[%+%-%*/%%&|%^:%.%?<>]") do
				start = start - 1
			end
			if not line:sub(start - 1, start - 1):find("%s") or not line:sub(1, start - 1):find("%S") then
				return nil
			end
			return start, at
		end
	end
end

local function inline_width(buf, row, col)
	local width = 0
	local marks = api.nvim_buf_get_extmarks(buf, -1, { row, 0 }, { row, col }, { details = true, type = "virt_text" })
	for _, mark in ipairs(marks) do
		local d = mark[4]
		if d.virt_text_pos == "inline" and d.ns_id ~= ns then
			for _, chunk in ipairs(d.virt_text) do
				width = width + api.nvim_strwidth(chunk[1])
			end
		end
	end
	return width
end

local function scanner(buf)
	local count = api.nvim_buf_line_count(buf)
	local lead = vim.trim(vim.bo[buf].commentstring:match("^(.-)%%s") or "")
	local cache = {}
	return function(row)
		if row < 0 or row >= count then
			return nil
		end
		local e = cache[row]
		if e == nil then
			e = false
			local line = api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
			local start, eq = operator(line)
			if start and (lead == "" or not vim.startswith(vim.trim(line), lead)) then
				e = {
					indent = line:match("^%s*"),
					col = start - 1,
					width = vim.fn.strdisplaywidth(line:sub(1, eq - 1)) + inline_width(buf, row, start - 1),
				}
			end
			cache[row] = e
		end
		return e or nil
	end
end

local function draw(buf, top, bot)
	local at = scanner(buf)
	local want, lo, hi = {}, top, bot
	local row = top
	while row <= bot do
		local e = at(row)
		if not e then
			row = row + 1
		else
			local first, last = row, row
			while first > top - reach and at(first - 1) and at(first - 1).indent == e.indent do
				first = first - 1
			end
			while last < bot + reach and at(last + 1) and at(last + 1).indent == e.indent do
				last = last + 1
			end
			lo, hi = math.min(lo, first), math.max(hi, last)
			local widths = {}
			for r = first, last do
				widths[#widths + 1] = at(r).width
			end
			table.sort(widths, function(a, b)
				return a > b
			end)
			local width = widths[1]
			for i = 2, #widths do
				if width - widths[i] <= outlier then
					break
				end
				width = widths[i]
			end
			for r = first, last do
				if at(r).width < width then
					want[r] = { col = at(r).col, pad = width - at(r).width }
				end
			end
			row = last + 1
		end
	end
	for _, mark in ipairs(api.nvim_buf_get_extmarks(buf, ns, { lo, 0 }, { hi + 1, 0 }, { details = true })) do
		local w = want[mark[2]]
		if w and w.col == mark[3] and w.pad == #mark[4].virt_text[1][1] then
			want[mark[2]] = nil
		else
			api.nvim_buf_del_extmark(buf, ns, mark[1])
		end
	end
	for r, w in pairs(want) do
		api.nvim_buf_set_extmark(buf, ns, r, w.col, {
			virt_text = { { string.rep(" ", w.pad) } },
			virt_text_pos = "inline",
			hl_mode = "combine",
		})
	end
end

function M.toggle()
	enabled = not enabled
	for _, buf in ipairs(api.nvim_list_bufs()) do
		api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	end
	vim.cmd.redraw({ bang = true })
end

function M.setup()
	api.nvim_set_decoration_provider(ns, {
		on_win = function(_, _, buf, top, bot)
			if enabled and vim.bo[buf].buftype == "" then
				local ok, err = pcall(draw, buf, top, bot)
				if not ok then
					M.toggle()
					vim.schedule(function()
						vim.notify("neru.align: turned off: " .. err, vim.log.levels.WARN)
					end)
				end
			end
		end,
	})
	vim.keymap.set("n", "<leader>=", M.toggle, { desc = "Toggle virtual alignment" })
end

return M
