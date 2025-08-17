local Path = require("plenary.path")
local _log = require("plenary.log")

local fzf_lua = require('fzf-lua')
local File = require('ansible-doc.file')
local Utils = require('ansible-doc.utils')
local Parse = require('ansible-doc.parse')
local Module = require('ansible-doc.module')
local Consts = require('ansible-doc.constants')

local Config = require('ansible-doc.config')
local health = require("ansible-doc.health")


local modules = {}

local M = {
    opts = {},
}


M.ansible_doc_user_command = function(opts)
    M.ansible_docs(M.opts)
end

M.ansible_doc = function(opts, module_name)
    local opts = opts or {}

    local opts = Utils.merge_tables_by_key(opts, M.opts)

    if vim.tbl_isempty(modules) then
        modules = Module.generate_names_list()
    end

    if not Utils.table_has_key(modules, module_name) then
        -- Return silently
        return 
    end

    local data = Module.get_raw_ansibledoc(module_name)
    data = Parse.ansibledoc_data(opts, data)
    Module.create_buffer(opts, module, data)

end

M.ansible_docs = function(opts)

    local opts = opts or {}

    local fzf_opts = Utils.merge_tables_by_key(opts.fzf_opts or {}, M.opts.fzf_opts)
    local opts = Utils.merge_tables_by_key(opts, M.opts)

    if vim.tbl_isempty(modules) then
        modules = Module.generate_names_list()
    end

    local bufn = vim.api.nvim_buf_get_name(0)

    fzf_opts.fn_transform = function(x)
        return fzf_lua.utils.ansi_codes.magenta(x)
    end

    fzf_opts.actions = {
        ['default'] = function(selected)
            local module = selected[1]
            M.ansible_doc(opts, module)
        end
    }

    fzf_opts.preview = function(item)
        local utils = fzf_lua.utils
        local ansi = utils.ansi_codes
        local dark_grey = ansi.dark_grey
        return dark_grey(modules[item[1]])
    end

    fzf_lua.fzf_exec( function(fzf_cb)
        local co = coroutine.running()
        for key,_ in pairs(modules) do
            fzf_cb(key)
        end
        fzf_cb()
    end, fzf_opts)
end

M.pre_compute_modules= function()
    table.foreach(modules, function(module, description)
        local module_path = Module.get_path(module)
        local ow = M.opts.pre_compute.overwrite or false
        local module_path_exists = Path:new(module_path):exists()

        if not module_path_exists or ow then
            local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
                if module_path_exists and ow then
                    File.removeFile(module_path)
                end
                File.writeFileAsync(module_path, obj.stdout)
            end)
        end
    end)

end

M.setup = function(opts)

    -- Merge options
    M.opts = Utils.merge_tables_by_key(opts, Config)

    -- Precompute modules only if enabled
    if M.opts.pre_compute.enable then
        M.pre_compute_modules()
    end

    -- Create user commands
    vim.api.nvim_create_user_command("AnsibleDoc", M.ansible_doc_user_command, {})

    vim.filetype.add({
        extension = {
            ansibledoc = "ansibledoc"
        },
        pattern = {
            [".ansibledoc"] = "ansibledoc"
        }
    })
end


return M
