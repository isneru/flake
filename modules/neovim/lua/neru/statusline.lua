local M = {}

local languages = {
	astro = "Astro",
	c = "C",
	cpp = "C++",
	css = "CSS",
	dockerfile = "Docker",
	gitcommit = "Git Commit Message",
	go = "Go",
	html = "HTML",
	java = "Java",
	javascript = "JavaScript",
	javascriptreact = "JavaScript JSX",
	json = "JSON",
	jsonc = "JSON with Comments",
	less = "Less",
	lua = "Lua",
	markdown = "Markdown",
	nix = "Nix",
	prisma = "Prisma",
	python = "Python",
	rust = "Rust",
	scss = "SCSS",
	sh = "Shell Script",
	sql = "SQL",
	svelte = "Svelte",
	tex = "LaTeX",
	toml = "TOML",
	typescript = "TypeScript",
	typescriptreact = "TypeScript JSX",
	typst = "Typst",
	vue = "Vue",
	xml = "XML",
	yaml = "YAML",
}

function M.diagnostics()
	local d = vim.diagnostic.count(0)
	local s = vim.diagnostic.severity
	return string.format(" %d   %d", d[s.ERROR] or 0, d[s.WARN] or 0)
end

function M.search()
	if vim.v.hlsearch == 0 or vim.fn.getreg("/") == "" then
		return ""
	end
	local ok, s = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
	if not ok or not s.total then
		return ""
	end
	if s.total == 0 then
		return " No results"
	end
	local total = s.incomplete == 2 and (s.maxcount .. "+") or tostring(s.total)
	local current = s.current == 0 and "?" or tostring(s.current)
	return string.format(" %s of %s", current, total)
end

function M.position()
	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	return string.format("Ln %d, Col %d", line, col + 1)
end

function M.indent()
	local width = vim.bo.shiftwidth
	if width == 0 then
		width = vim.bo.tabstop
	end
	return (vim.bo.expandtab and "Spaces: " or "Tab Size: ") .. width
end

function M.encoding()
	local enc = vim.bo.fileencoding
	if enc == "" then
		enc = vim.o.encoding
	end
	return enc:upper()
end

function M.eol()
	return ({ unix = "LF", dos = "CRLF", mac = "CR" })[vim.bo.fileformat] or ""
end

function M.language()
	local ft = vim.bo.filetype
	if ft == "" then
		return "Plain Text"
	end
	return languages[ft] or (ft:sub(1, 1):upper() .. ft:sub(2))
end

function M.formatter()
	local ok, conform = pcall(require, "conform")
	if not ok then
		return ""
	end
	local list = conform.list_formatters_to_run and conform.list_formatters_to_run(0) or conform.list_formatters(0)
	for _, f in ipairs(list or {}) do
		if f.available ~= false then
			return f.name:sub(1, 1):upper() .. f.name:sub(2)
		end
	end
	return ""
end

return M
