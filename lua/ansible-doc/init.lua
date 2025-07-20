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

local function appendFileAsync(path, data)
    uv.fs_open(path, "a", 438, function(err, fd)
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

local function removeFile(path)
    local ok, err = os.remove(path)
    if not ok then
        P(err)
        return false
    end
    return true
end

local M = {
    docs = {},
    opts = {
        syntax = {
            optional = {
                start= "~",
                close = "~"
            },
            required = {
                start = "[",
                close = "]"
            },
            attr = {
                start = "|",
                close = "|"
            }
        }
    }
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

M.__key_in_table = function(t, key)

    if type(t) ~= "table" then
        return false
    end

    local keys = vim.tbl_keys(t)

    if t[key] ~= nil then
        return true
    end

    return false
end

M.__nested_options = function(options, depth, result)
    local result = result or {}
    local inserted_description = false

    table.sort(options)

    for attr, value in pairs(options) do
        local str_attr = attr
        if depth == 1 then
            if M.__key_in_table(value, "required") and vim.fn.string(value["required"]) == "v:true" then
                str_attr = M.opts.syntax.required.start .. attr .. M.opts.syntax.required.close
            else 
                str_attr = M.opts.syntax.optional.start .. attr .. M.opts.syntax.optional.close
            end
            if M.__key_in_table(value, "description") and not inserted_description then
                if type(value["description"]) == "table" then
                    value = table.concat(value["description"])
                else
                    value = vim.fn.string(value["description"])
                end
                table.insert(result, string.rep("\t", depth) .. str_attr.. ": " .. value)
                inserted_description = true
            end
        elseif attr ~= "description" then
            str_attr = M.opts.syntax.attr.start .. attr .. M.opts.syntax.attr.close
            if type(value) == "table" and not vim.tbl_islist(value) then
                if not inserted_description then
                    table.insert(result, string.rep("\t", depth) .. str_attr.. ":   ")
                end
                result = M.__nested_options(value, depth + 1, result)
            else 
                local str_value = vim.fn.string(value)
                table.insert(result, string.rep("\t", depth) .. str_attr .. ": " .. str_value .. "")
            end
        end
        inserted_description = false
    end
    table.insert(result,"")
    return result
end

M.__generate_top_level_options = function(options, depth, result)
    local result = result or {}
    local inserted_description = false

    table.sort(options)

    for attr, value in pairs(options) do
        local str_attr = attr
        if M.__key_in_table(value, "required") and vim.fn.string(value["required"]) == "v:true" then
            str_attr = M.opts.syntax.required.start .. attr .. M.opts.syntax.required.close
        else 
            str_attr = M.opts.syntax.optional.start .. attr .. M.opts.syntax.optional.close
        end
        if M.__key_in_table(value, "description") and not inserted_description then
            if type(value) == "table" then
                if vim.islist(value) then
                    P("IS A LIST!")
                    value = table.concat(value["description"])
                else
                    P(value)
                    value = vim.fn.string(value["description"])
                end
            end
            table.insert(result, string.rep("\t", depth) .. str_attr.. ": " .. value)
            inserted_description = true
        end
    end
end

M.__ansibledoc_generate_options = function(options, result)
    local result = result or {}
    if options == nil then
        return
    end

    table.insert(result, "".."* OPTIONS")
    table.insert(result, "Required options are shown as:\t" .. M.opts.syntax.required.start .. "required" .. M.opts.syntax.required.close )
    table.insert(result, "Optional options are shown as:\t" .. M.opts.syntax.optional.start .. "optional" .. M.opts.syntax.optional.close )
    table.insert(result, "Attributes are shown as:\t" .. M.opts.syntax.attr.start .. "attribute" .. M.opts.syntax.attr.close )
    table.insert(result, "")

    M.__nested_options(options, 1, result)

    table.insert(result, "")
end

M.__ansibledoc_generate_examples = function(examples, result)
    local result = result or {}
    if examples == nil then
        return
    end

    local ex_table = vim.split(examples, "\n")

    table.insert(result, "".."* EXAMPLES")
    table.insert(result, "")
    table.insert(result, "```yamlStart")
    for _,example in ipairs(ex_table) do
        table.insert(result, example)
    end
    table.insert(result, "```yamlEnd")
    table.insert(result, "")
end

M.__ansibledoc_generate_author = function(author, result)
    local result = result or {}
    if author == nil then
        return
    end
    table.insert(result, "".."* AUTHOR: ")
    table.insert(result,"")
    if type(author) == "table" then
        table.insert(result, "\t".. table.concat(author, ","))
    else
        table.insert(result, "\t".. author)
    end
    table.insert(result,"")
end

M.__ansibledoc_generate_notes = function(notes, result)
    local result = result or {}
    if notes == nil then
        return
    end
    table.insert(result, "".."* NOTES: ")
    table.insert(result,"")
    if type(notes) == "table" then
        table.foreach(notes, function(_,note) 
            table.insert(result, "\t* " .. note)
        end)
    end
    table.insert(result, "")
end

M.__ansibledoc_generate_attributes = function(attributes, result)
    local result = result or {}
    if attributes == nil then
        return
    end
    table.insert(result, "".."* ATTRIBUTES: ")
    table.insert(result,"")
    for attr, value in pairs(attributes) do
        local str_attr = attr
        str_attr = M.opts.syntax.attr.start .. attr .. M.opts.syntax.attr.close
        local str_value = vim.fn.string(value)
        table.insert(result, string.rep("\t", 1) .. str_attr .. ": ") 
        if type(value) == "table" then
            for key, val in pairs(value) do
                if vim.islist(val) then
                    val = table.concat(val, ". ")
                end
                table.insert(result, string.rep("\t", 2) .. key .. ": " .. vim.fn.string(val))
            end
        end
        table.insert(result, "")
    end
    table.insert(result, "")
end

M.__ansibledoc_generate_retvalues = function(ret, result)
    local result = result or {}
    if type(ret) ~= "table" then
        return
    end
    table.insert(result, "".."* RETURN: ")
    table.insert(result,"")
    for attr, value in pairs(ret) do
        local str_attr = attr
        str_attr = M.opts.syntax.attr.start .. attr .. M.opts.syntax.attr.close
        local str_value = vim.fn.string(value)
        table.insert(result, string.rep("\t", 1) .. str_attr .. ": ") 
        for key, val in pairs(value) do
            table.insert(result, string.rep("\t", 2) .. key .. ": " .. vim.fn.string(val))
        end
        table.insert(result, "")
    end
    table.insert(result, "")
end

local parse_to_ansible_doc = function(str_data)

    local result = {}

    local json_data = vim.json.decode(str_data)
    local module_name = vim.fn.keys(json_data)[1]

    -- Top level keys
    local docs = json_data[module_name]["doc"]
    local examples = json_data[module_name]["examples"]
    local ret = json_data[module_name]["return"]
    local metadata = json_data[module_name]["metadata"]

    -- Doc keys
    local options = docs["options"]
    local author = docs["author"]
    local description = docs["description"]
    local attributes = docs["attributes"]
    local notes = docs["notes"]

    table.insert(result, "# Module: [" ..module_name .. "]")
    if type(description) == "table" then
        description = table.concat(description, "")
    end
    table.insert(result, description .. "")
    table.insert(result, "")

    M.__ansibledoc_generate_author(author, result)
    M.__ansibledoc_generate_options(options, result)
    M.__ansibledoc_generate_retvalues(ret, result)
    M.__ansibledoc_generate_examples(examples, result)
    M.__ansibledoc_generate_attributes(attributes, result)
    M.__ansibledoc_generate_notes(notes, result)

    return result
end


local create_module_buffer = function(module, data)
    data = parse_to_ansible_doc(data)
    for i, v in ipairs(data) do
        data[i] = v:gsub("\n", " ")  -- Replace with space
    end
    vim.schedule( function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, 
        data
    )
    -- vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "ansibledoc"
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
    vim.keymap.set('n', 'q', '<cmd>bprev<CR>', {buffer = buf, nowait = true})
end)
end

-- Module docs will be stored locally in stdpath("data")/ansible-doc/dir1/dir2/module.md
M.parse_module = function(module)
end

M.__create_module_file = function(module, path)
    local data = {}
    local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
        writeFileAsync(path, obj.stdout)
        data = obj.stdout
    end)
    output:wait()
    return data
end

M.get_parsed_module_data = function(module)
    local module_path = M.get_module_path(module)
    local data = {}
    if not Path:new(module_path):exists() then
        data = M.__create_module_file(module, module_path)
    else
        data = readFileSync(module_path)
        -- If the file is empty recreate it
        if string.len(data) == 0 then
            removeFile(module_path)  -- Delete empty file
            return M.get_parsed_module_data(module) -- Recreate it
        end
    end

    return parse_to_ansible_doc(data)
end

M.test_modules = function()
    if vim.tbl_isempty(M.docs) then
        M.populate_modules_doc(false) 
    end

    local errors_path = "/tmp/ansible-doc.errors.txt"
    writeFileAsync(errors_path, "") -- Overwrite it with nothing

    local keys = vim.fn.keys(M.docs)
    local total = #keys
    local curr = 0
    local errors = 0
    local function step()
        curr = curr + 1
        module = keys[curr]

        vim.api.nvim_echo({{string.format("Testing progress: %d / %d", curr, total)}, {''}}, false, {})

        local is_correct, err_msg = pcall(M.get_parsed_module_data, module)
        if not is_correct then
            errors = errors + 1
            local data = {
                module,
                err_msg,
                "\n"
            }
            appendFileAsync(errors_path, data)
        end

        if curr < total then
            vim.defer_fn(step, 10) -- next in 10 ms
        else
            if errors > 0 then
                vim.api.nvim_echo({{string.format("Found %d errors.\n", errors)}, {string.format("Open an issue at GitHub showing the contents of the file at %s", errors_path)}}, false, {})
            else
                vim.api.nvim_echo({{"Done!"}, {""}}, false, {})
            end
        end
    end
    step()
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
            local data = M.get_parsed_module_data(module)
            create_module_buffer(module, data)
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
                writeFileAsync(module_path, obj.stdout)
            end)
        end
    end)

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
        },
        pattern = {
            [".ansibledoc"] = "ansibledoc"
        }
    })
end


return M
