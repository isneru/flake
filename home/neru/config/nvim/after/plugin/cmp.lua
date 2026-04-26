local cmp = require("cmp")

cmp.setup({
	formatting = {
		format = function(entry, vim_item)
			-- source
			vim_item.menu = ({
				buffer = "[buffer]",
				nvim_lsp = "[lsp]",
				luasnip = "[luasnip]",
				nvim_lua = "[lua]",
			})[entry.source.name]
			return vim_item
		end,
	},
	window = {
		completion = cmp.config.window.bordered({ border = "single" }),
		documentation = {
			border = "single",
			winhighlight = "normal:normal,floatborder:floatborder,cursorline:visual,search:none",
			max_width = 80,
			max_height = 20,
		},
	},
	mapping = {
		["<c-b>"] = cmp.mapping.scroll_docs(-4),
		["<c-f>"] = cmp.mapping.scroll_docs(4),
		["<c-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
		["<c-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),

		["<tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.confirm({ select = true })
			else
				fallback()
			end
		end, { "i", "s" }),
	},

	sources = cmp.config.sources({
		{
			name = "nvim_lsp",
			---@param entry cmp.entry
			---@param ctx cmp.context
			entry_filter = function(entry, ctx)
				if ctx.filetype ~= "vue" then
					return true
				end

				local cursor_before_line = ctx.cursor_before_line
				if cursor_before_line:sub(-1) == "@" then
					return entry.completion_item.label:match("^@")
				elseif cursor_before_line:sub(-1) == ":" then
					return entry.completion_item.label:match("^:") and not entry.completion_item.label:match("^:on%-")
				else
					return true
				end
			end,
		},
		{ name = "buffer" },
		{ name = "path" },
		{ name = "luasnip" },
		{ name = "nvim_lua" },
	}),
	experimental = {
		ghost_text = false,
	},
})

cmp.event:on("menu_closed", function()
	local bufnr = vim.api.nvim_get_current_buf()
	vim.b[bufnr]._vue_ts_cached_is_in_start_tag = nil
end)
