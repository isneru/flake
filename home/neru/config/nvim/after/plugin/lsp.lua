vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
		end
	end,
})

local lsp_present, _ = pcall(require, "lspconfig")

if not lsp_present then
	vim.notify("lspconfig not present", vim.log.levels.ERROR)
	return
end

vim.lsp.config("*", {
	root_markers = { ".git" },
	capabilities = {
		textDocument = {
			semanticTokens = {
				multilineTokenSupport = true,
			},
		},
	},
})

local servers = {
	-- keep-sorted start block=yes newline_separated=yes
	astro = {
		settings = {
			typescript = {
				tsdk = vim.fn.expand("~") .. "/.npm-global/lib/node_modules/typescript/lib",
			},
		},
	},

	clangd = {},

	emmet_language_server = {
		filetypes = {
			"vue",
			"astro",
			"css",
			"html",
			"javascript",
			"javascriptreact",
			"typescriptreact",
		},
	},

	jdtls = {},

	jsonls = {
		settings = {
			json = {
				validate = { enable = true },
				schemas = {
					{
						fileMatch = { "package.json" },
						url = "https://www.schemastore.org/package.json",
					},
					{
						fileMatch = { "tsconfig*.json" },
						url = "https://www.schemastore.org/tsconfig.json",
					},
				},
			},
		},
	},

	just = {},

	lua_ls = {
		settings = {
			Lua = {
				runtime = {
					version = "LuaJIT",
				},
				diagnostics = {
					globals = { "vim" },
				},
				hint = { enable = true },
			},
		},
	},

	nil_ls = {},

	nixd = {},

	rust_analyzer = {},

	tailwindcss = {
		filetypes = {
			"vue",
			"astro",
			"javascriptreact",
			"typescriptreact",
			"html",
			"css",
		},
	},

	taplo = {},

	tinymist = {
		settings = {
			exportPdf = "onSave",
			formatterMode = "typstyle",
		},
	},

	vtsls = {},

	yamlls = {
		settings = {
			yaml = {
				completion = true,
				validate = true,
				suggest = {
					parentSkeletonSelectedFirst = true,
				},
				schemas = {
					["https://www.schemastore.org/github-workflow.json"] = ".github/workflows/*",
					["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.{yml,yaml}",
				},
			},
			redhat = {
				telemetry = {
					enable = false,
				},
			},
		},
	},
	-- keep-sorted end
}
for server, config in pairs(servers) do
	vim.lsp.config(server, config)
	vim.lsp.enable(server)
end

vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	underline = true,
	update_in_insert = false,
	float = {
		focusable = false,
		style = "minimal",
		border = "single",
		source = "if_many",
		header = "",
		prefix = "",
	},
})

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
	border = "single",
	max_width = 80,
})

vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { noremap = true, silent = true, desc = "LSP Hover Documentation" })
