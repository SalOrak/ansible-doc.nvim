local M = {
    ansible_version = {
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
}


M.ansible_version = function()
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


        M.ansible_version= {
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

    end)
    stdout:wait()

    return M.ansible_version
end

return M
