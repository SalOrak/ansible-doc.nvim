local _path = require("plenary.path")
local _log = require("plenary.log")

local uv = vim.uv


local M = {
    docs = {},
}

-- @param path String (path): File to read
local readFileSync = function (path)
    local fd = assert(uv.fs_open(path, "r", 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

-- @param path String (path): File to write data to.
-- @param data Any: Data to write to the file.
local writeFileSync = function (path, data)
    local fd = assert(uv.fs_open(path, "w", 438))
    local res = assert(uv.fs_write(fd, data))
    assert(uv.fs_close(fd))
    return res
end


local data_path = string.format("%s/ansible-docs", vim.fn.stdpath("data"))
local ansible_modules_filepath= string.format("%s/modules.json", data_path)

local data_path_exists = false

local ansible_version = {
        core_version = {},
        config_file = {},
        module_search_path = {},
        ansible_python_location = {},
        ansible_collection_location = {},
        ansible_executable_location = {},
        python_version = {},
        jinja_version = {},
        libyaml = {},
}

local parse_ansible_version = function()
    local version = {}

    local cmd = vim.api.nvim_parse_cmd("!ansible-doc --version", {})
    cmd.mods.silent = true
    local output = vim.api.nvim_cmd(cmd, {output = true})
    local splitted = vim.split(output, '\n')
    local clean_data = {}
    for value in vim.iter(splitted) do
        if value ~= "" then
            table.insert(clean_data, vim.trim(value))
        end
    end

    local iter = vim.iter(clean_data)
    iter:skip(1) -- Skip the command

    local core_version = vim.split(string.match(iter:next(), "%[(.-)%]"), ' ')[2]
    local config_file = vim.split(iter:next(), '=')[2] 
    local raw_module_search_path = vim.split(iter:next(), '=')[2]
    local ansible_python_location = vim.split(iter:next(), '=')[2] 
    local ansible_collection_location = vim.split(iter:next(), '=')[2] 
    local ansible_executable_location = vim.split(iter:next(), '=')[2] 
    local python_version = vim.split(vim.split(iter:next(), '=')[2], ' ')[2]
    local jinja_version = vim.split(iter:next(), '=')[2] 
    local libyaml = vim.split(iter:next(), '=')[2] 

    local module_search_path = {}
    for value in string.gmatch(raw_module_search_path, "'(.-)'") do
        table.insert(module_search_path, value)
    end


    ansible_version= {
        core_version = vim.trim(core_version),
        config_file = vim.trim(config_file),
        module_search_path = module_search_path,
        ansible_python_location = vim.trim(ansible_python_location),
        ansible_collection_location = ansible_collection_location,
        ansible_executable_location = vim.trim(ansible_executable_location),
        python_version = vim.trim(python_version),
        jinja_version = vim.trim(jinja_version),
        libyaml = vim.trim(libyaml),
    }

    setmetatable(M, ansible_version)
end

local function ensure_data_path_exists()
    if data_path_exists then
        return
    end
    local path = _path:new(data_path)
    if not path:exists() then
        path:mkdir()
    end
    data_path_exists = true
end

local function is_ansible_installed()
    local cmd = vim.api.nvim_parse_cmd("!ansible-doc --version", {})
    cmd.mods.silent = true
    local ok, err = pcall(vim.api.nvim_cmd(cmd, {}))
    if err then
        return err
    else 
        return ok
    end
end

local function generate_ansible_modules_docs()
    local cmd = vim.api.nvim_parse_cmd("!ansible-doc --json --list > " .. ansible_modules_filepath, {})
    cmd.mods.silent = true
    local ok, err = pcall(vim.api.nvim_cmd(cmd, {output=false}))
    return {ok, err}
end


M.get_ansible_docs = function()
    local path = _path:new(ansible_modules_filepath)
    if not path:exists() then
        generate_ansible_modules_docs()
    end 

    if not vim.tbl_isempty(M.docs) then
        return M.docs
    end

    return readFileSync(ansible_modules_filepath)
end

M.populate_modules_doc = function()
    ensure_data_path_exists() 

    if not is_ansible_installed() then
        _log.error("Ansible is not installed properly. Make sure `ansible-doc` is available from the terminal.")
        return false
    end

    M.docs = vim.json.decode(M.get_ansible_docs())
    return true
end



local parse_module = function(module)
    P(module)
end

M.ansible_docs = function()
    local fzf = require('fzf-lua')
    fzf.fzf_exec( function(fzf_cb)
        local co = coroutine.running()

        for key,_ in pairs(M.docs) do
            fzf_cb(key)
        end
        fzf_cb()
    end,
    {
        actions = {
            ['default'] = function(selected)
                local path = M.docs[selected[1]]
                local cmd = vim.api.nvim_parse_cmd("!ansible-doc --json " .. selected[1], {})
                cmd.mods.silent = true;
                local output
                P(data)
            end
        }
    })
end

M.setup = function(opts)
    local has_fzflua, _ = pcall(require, "fzf-lua")
    -- Make sure fzf-lua is installed
    if not has_fzflua then
        _log.error("`fzf-lua` is a required dependency. Please install it!")
        return false
    end

    -- Parse ansible version data
    local can_parse_version = pcall(parse_ansible_version)
    if not can_parse_version then
        _log.error("Can't parse the output of `ansible-docs version`")
        return false
    end

    -- Populate the docs. Afterwards do whatever you have to do
    if not M.populate_modules_doc() then
        return false
    end 
end


return M
