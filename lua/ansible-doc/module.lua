local File = require('ansible-doc.file')
local Path = require('plenary.path')
local Consts = require('ansible-doc.constants')

local M = {}

---@brief Creates a file containing the JSON ansible documentation of the module
--- using the `ansible-doc` cli.
---
---@param module string: Module name to generate the docs and create the file.
---@param path string: Path where the file should be generated at.
---
---@return data table: Table containing the JSON documentation.
M.generate_json_ansible_docs= function(module, path)
    local data = {}
    local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
        File.writeFileAsync(path, obj.stdout)
        data = obj.stdout
    end)
    output:wait()
    return data
end

---@brief Returns the path where the module file lives in the disk.
--- If the path to the file does not exists, it creates it along the way.
---
--- @param module string: Module name to get the path from
---
--- @return path string: Path where the module unparsed documentation is stored.
M.get_path = function(module)
    local module_path = string.gsub(module, "%.", "/")
    local split_path = vim.split(module_path, "/")

    local str_path = Consts.data_path .. "/" .. split_path[1] .. "/" .. split_path[2] .. "/" .. split_path[3]

    local path = Path:new(str_path)

    if path:exists() then
        return str_path 
    end

    -- Create the path to the file. 
    -- Reverse it because it starts from the file.
    local parents = vim.fn.reverse(path:parents())
    for _, path in pairs(parents) do
        local tmp = Path:new(path)
        if not tmp:exists() then
            tmp:mkdir()
        end
    end

    return str_path
end

---@brief Generate the list of modules names available in our ansible path.
--- The generation using ansible itself is quite slow and 
--- generating it on startup is slow as well as a waste of cpu usage.
--- So instead, the list will be stored on disk (tradeoff) and read on startup.
---
---@param overwrite boolean: Whether to force the list of module names or not.
---@param listnames table: Contains all the module names. By default is empty and optional.
---
---@return list table: List with all the modules names. 
M.generate_names_list = function(overwrite, listnames)
    Consts.ensure_data_path_exists() 

    local list = listnames or {}
    local path = Path:new(Consts.ansible_modules_filepath)
    if not path:exists() or overwrite then
        local stdout = vim.system({"ansible-doc", "--list", "--json"}, {text = true}, function(obj)
            list = vim.json.decode(obj.stdout)

            -- Asynchronously store data
            File.writeFileAsync(Consts.ansible_modules_filepath, obj.stdout)
        end)
        stdout:wait()
    end 

    if vim.tbl_isempty(list) then
        -- Read file and save is as json
        local data = File.readFileSync(Consts.ansible_modules_filepath)
        list = vim.json.decode(data)
    end

    return list
end

---@brief Creates the documentation buffer itself.
---
---@param module string: Module name. Used to set the buffer name.
---@param data table: Flat table containing the final documentation to
---                   be inserted in the buffer as it is.
M.create_buffer = function(module, data)
    for i, v in ipairs(data) do
        -- Writing on a buffer does not allow newlines.
        -- Newlines are written automatically by each entry in the table.
        -- This may change the way the final output looks but I don't think
        -- it is a "critical" or "horrible" change.
        data[i] = v:gsub("\n", " ")  
    end

    local buffer_name = string.format("%s", module)

    vim.schedule( function()
        local bufnr = vim.fn.bufnr(buffer_name)
        -- Found a buffer with the same name.
        if bufnr > 0 then
            vim.api.nvim_win_set_buf(0, bufnr)
            return
        end

        -- TODO: Users should be able to select whether they prefer
        -- to have the buffer listed or not.
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, data)
        vim.api.nvim_buf_set_name(buf, buffer_name)
        vim.api.nvim_win_set_buf(0, buf)
        vim.bo[buf].filetype = "ansibledoc"
        vim.bo[buf].readonly = true
        vim.bo[buf].modifiable = false
        vim.keymap.set('n', 'q', '<cmd>bprev<CR>', {buffer = buf, nowait = true})
    end)
end


---@brief: Generates the file containing all the documentation for the module
--- passed. If the file already exists then it is only read.
--- Afterwards the data is returned.
---
--- @param module string: Module name to extract the documentation from.
---
--- @returns data table: Table containing documentation for the module.
M.get_raw_ansibledoc = function(module)
    local module_path = M.get_path(module) 
    local data = {}
    if not Path:new(module_path):exists() then
        data = M.generate_json_ansible_docs(module, module_path)
    else
        data = File.readFileSync(module_path)
        -- If the file is empty recreate it
        if string.len(data) == 0 then
            File.removeFile(module_path)  -- Delete empty file
            return M.get_raw_ansibledoc(module) -- Recreate it
        end
    end

    return data
end

return M

