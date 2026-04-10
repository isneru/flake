require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        vue = { "prettierd", "prettier", stop_after_first = true },
        astro = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        nix = { "nixfmt" },
    },
    format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
    },
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
    require("conform").format({ timeout_ms = 500, lsp_format = "fallback" })
end, { desc = "Format buffer or selection" })
