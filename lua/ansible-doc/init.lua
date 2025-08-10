local Path = require("plenary.path")
local _log = require("plenary.log")

local fzf_lua = require('fzf-lua')
local File = require('ansible-doc.file')
local Utils = require('ansible-doc.utils')
local Parse = require('ansible-doc.parse')
local Module = require('ansible-doc.module')
local Consts = require('ansible-doc.constants')

local health = require("ansible-doc.health")

local M = {
    docs = {},
    opts = {
    },
}

M.ansible_docs = function(opts)
    if vim.tbl_isempty(M.docs) then
        M.docs = Module.generate_names_list()
    end

    local bufn = vim.api.nvim_buf_get_name(0)

    opts = opts or {}
    opts.prompt = "Ansible Modules > "
    opts.fn_transform = function(x)
        return fzf_lua.utils.ansi_codes.magenta(x)
    end
    opts.actions = {
        ['default'] = function(selected)
            local module = selected[1]
            local data = Module.get_raw_ansibledoc(module)
            data = Parse.ansibledoc_data(data)
            Module.create_buffer(module, data)
        end
    }

    opts.preview = function(item)
        local utils = fzf_lua.utils
        local ansi = utils.ansi_codes
        local dark_grey = ansi.dark_grey
        -- local data = M.get_parsed_module_data(module)
        -- return dark_grey(table.concat(data, "\n"))
        return dark_grey(M.docs[item[1]])
    end

    fzf_lua.fzf_exec( function(fzf_cb)
        local co = coroutine.running()
        for key,_ in pairs(M.docs) do
            fzf_cb(key)
        end
        fzf_cb()
    end, opts)
end

M.cache_modules = function()
    table.foreach(M.docs, function(module, description)
        local module_path = M.get_module_path(module)
        if not Path:new(module_path):exists() then
            local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
                File.writeFileAsync(module_path, obj.stdout)
            end)
        end
    end)

end

M.setup = function(opts)
    -- Parse ansible version data
    M.parse_ansible_version()

    -- Populate the docs. Afterwards do whatever you have to do
    local ok, err_msg = pcall(M.populate_modules_doc)
    if not ok then
        _log.error("Error whilst generating the list of modules.")
        _log.error(string.format("Error message: %s", err_msg))
        return 
    end 


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
