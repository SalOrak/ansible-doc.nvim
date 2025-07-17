local Path = require("plenary.path")
local _log = require("plenary.log")
local fzf_lua = require('fzf-lua')

local health = require("ansible-doc.health")

local uv = vim.uv

local function writeFileAsync(path, data)
    uv.fs_open(path, "w", 438, function(err, fd)
        assert(not err, err)
        uv.fs_write(fd, data, -1, function(err, written)
            assert(not err, err)
            uv.fs_close(fd, function(err)
                assert(not err, err)
            end)
        end)
    end)
end

local function readFileSync(path)
    local fd = assert(uv.fs_open(path, "r", 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

local M = {
    docs = {},
}

local data_path = string.format("%s/ansible-doc", vim.fn.stdpath("data"))
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

M.parse_ansible_version = function()
    local version = {}

    local stdout = vim.system({"ansible-doc", "--version"}, {text = true}, function(obj)
        local splitted = vim.split(obj.stdout, '\n')
        local clean_data = {}
        for value in vim.iter(splitted) do
            if value ~= "" then
                table.insert(clean_data, vim.trim(value))
            end
        end


        local iter = vim.iter(clean_data)

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
    end)
end

local function ensure_data_path_exists()
    if data_path_exists then
        return
    end
    local path =Path:new(data_path)
    if not path:exists() then
        path:mkdir()
    end
    data_path_exists = true
end

M.populate_modules_doc = function(overwrite)
    ensure_data_path_exists() 

    local path =Path:new(ansible_modules_filepath)
    if not path:exists() or overwrite then
        local stdout = vim.system({"ansible-doc", "--list", "--json"}, {text = true}, function(obj)
            M.docs = vim.json.decode(obj.stdout)

            -- Asynchronously store data
            writeFileAsync(ansible_modules_filepath, obj.stdout)
        end)
        stdout:wait()
    end 

    if vim.tbl_isempty(M.docs) then
        -- Read file and save is as json
        M.docs = vim.json.decode(readFileSync(ansible_modules_filepath))
    end

    return true
end

M.get_module_path= function(module)
    local module_path = string.gsub(module, "%.", "/")
    local split_path = vim.split(module_path, "/")
    local ansible_doc_path = vim.fn.stdpath("data") .. "/ansible-doc/" 

    local str_path = ansible_doc_path .. "/" .. split_path[1] .. "/" .. split_path[2] .. "/" .. split_path[3]

    local path = Path:new(str_path)

    if path:exists() then
        return str_path 
    end
    
    local parents = vim.fn.reverse(path:parents())
    for _, path in pairs(parents) do
        local tmp = Path:new(path)
        if not tmp:exists() then
            tmp:mkdir()
        end
    end

    return str_path
end

local create_module_buffer = function(module, data)
    vim.schedule( function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "# My Heading",
            "",
            "This is some text.",
            "IMPORTANT: Do this!",
            "",
            "```yaml",
            "foo: bar",
            "```",
        })
        vim.cmd("vsplit")
        vim.api.nvim_win_set_buf(0, buf)
        vim.bo[buf].filetype = "ansibledoc"
        vim.bo[buf].readonly = true
        vim.bo[buf].modifiable = false
        vim.keymap.set('n', 'q', '<cmd>close<CR>', {buffer = buf, nowait = true})
    end)
end

-- Module docs will be stored locally in stdpath("data")/ansible-doc/dir1/dir2/module.md
M.parse_module = function(module)
    local module_path = M.get_module_path(module)
    if not Path:new(module_path):exists() then
        local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
            create_module_buffer(module, vim.json.decode(obj.stdout))
            writeFileAsync(module_path, obj.stdout)
        end)
        output:wait()
    else
        create_module_buffer(module, readFileSync(module_path))
    end
end

M.ansible_docs = function(opts)
    if vim.tbl_isempty(M.docs) then
        M.populate_modules_doc(false) 
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
            M.parse_module(module)
        end
    }

    opts.preview = function(item)
        local utils = fzf_lua.utils
        local ansi = utils.ansi_codes
        local dark_grey = ansi.dark_grey
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

M.setup = function(opts)
    -- Parse ansible version data
    M.parse_ansible_version()

    -- Populate the docs. Afterwards do whatever you have to do
    if not M.populate_modules_doc() then
        return false
    end 

    vim.filetype.add({
        extension = {
            ansibledoc = "ansibledoc"
        }
    })
end


return M
