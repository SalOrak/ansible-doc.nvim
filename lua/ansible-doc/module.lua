local File = require('ansible-doc.file')
local Path = require('plenary.path')
local Consts = require('ansible-doc.constants')

local M = {}

M.create_file = function(module, path)
    local data = {}
    local output = vim.system({"ansible-doc", "--json", module}, {text = true}, function(obj)
        File.writeFileAsync(path, obj.stdout)
        data = obj.stdout
    end)
    output:wait()
    return data
end

M.get_path = function(module)
    local module_path = string.gsub(module, "%.", "/")
    local split_path = vim.split(module_path, "/")

    local str_path = Consts.data_path .. "/" .. split_path[1] .. "/" .. split_path[2] .. "/" .. split_path[3]

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

M.create_buffer = function(module, data)
    for i, v in ipairs(data) do
        data[i] = v:gsub("\n", " ")  -- Replace with space
    end
    vim.schedule( function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, data)
        vim.api.nvim_win_set_buf(0, buf)
        vim.bo[buf].filetype = "ansibledoc"
        vim.bo[buf].readonly = true
        vim.bo[buf].modifiable = false
        vim.keymap.set('n', 'q', '<cmd>close<CR>', {buffer = buf, nowait = true})
    end)
end

M.get_raw_ansibledoc = function(module)
    local module_path = M.get_path(module)
    local data = {}
    if not Path:new(module_path):exists() then
        data = M.create_file(module, module_path)
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

