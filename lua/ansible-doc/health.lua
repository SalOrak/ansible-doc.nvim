local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

M.check = function()
    start("ansible [required]")
    if vim.fn.executable("ansible") == 0 then
        error("ansible not found")
    else 
        ok("ansible found")
    end

    start("ansible-doc [required]")
    if vim.fn.executable("ansible-doc") == 0 then
        error("ansible-doc not found")
    else 
        ok("ansible-doc found")
    end

    start("fzf-lua [required]")
    local has_fzf, _ = pcall(require, 'fzf-lua')
    if not has_fzf then
        error("fzf-lua dependency not found")
    else 
        ok("fzf-lua is correctly installed")
    end
end

return M
