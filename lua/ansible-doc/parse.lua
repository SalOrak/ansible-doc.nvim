local Consts = require('ansible-doc.constants')
local Utils = require('ansible-doc.utils')

local M = {}

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

        return ansible_version
    end)
end

M.ansibledoc_author = function(author, result)
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

M.ansibledoc_notes = function(notes, result)
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

M.ansibledoc_attributes = function(attributes, result)
    local result = result or {}
    if attributes == nil then
        return
    end
    table.insert(result, "".."* ATTRIBUTES: ")
    table.insert(result,"")
    for attr, value in pairs(attributes) do
        local str_attr = attr
        str_attr = Consts.syntax.attr.start .. attr .. Consts.syntax.attr.close
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

M.ansibledoc_return = function(ret, result)
    local result = result or {}
    if type(ret) ~= "table" then
        return
    end
    table.insert(result, "".."* RETURN: ")
    table.insert(result,"")
    for attr, value in pairs(ret) do
        local str_attr = attr
        str_attr = Consts.syntax.attr.start .. attr .. Consts.syntax.attr.close
        local str_value = vim.fn.string(value)
        table.insert(result, string.rep("\t", 1) .. str_attr .. ": ") 
        for key, val in pairs(value) do
            table.insert(result, string.rep("\t", 2) .. key .. ": " .. vim.fn.string(val))
        end
        table.insert(result, "")
    end
    table.insert(result, "")
end

M.ansibledoc_examples = function(examples, result)
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

M.ansibledoc_options = function(options, result)
    local result = result or {}
    if options == nil then
        return
    end

    table.insert(result, "".."* OPTIONS")
    table.insert(result, "Required options are shown as:\t" .. Consts.syntax.required.start .. "required" .. Consts.syntax.required.close )
    table.insert(result, "Optional options are shown as:\t" .. Consts.syntax.optional.start .. "optional" .. Consts.syntax.optional.close )
    table.insert(result, "Attributes are shown as:\t" .. Consts.syntax.attr.start .. "attribute" .. Consts.syntax.attr.close )
    table.insert(result, "")

    M.__ansibledoc_top_options(options, 1, result)

    table.insert(result, "")
end

local option_type = {
    Attribute = {
        start = Consts.syntax.attr.start,
        close = Consts.syntax.attr.close
    },
    Required = {
        start = Consts.syntax.required.start,
        close = Consts.syntax.required.close
    },
    Optional = {
        start = Consts.syntax.optional.start,
        close = Consts.syntax.optional.close
    },
}

local ignore_options = {
    "version_added_collection",
}

M.__colorize_option = function(attr, value)
    local str_attr
    if Utils.table_has_key(value, "required") then
        if vim.fn.string(value["required"]) == "v:true" then
            str_attr = Consts.syntax.required.start .. attr .. Consts.syntax.required.close
        else
            str_attr = Consts.syntax.optional.start .. attr .. Consts.syntax.optional.close
        end
    else 
        str_attr = Consts.syntax.attr.start .. attr .. Consts.syntax.attr.close
    end

    return str_attr
end

-- Returns whether the option table contains a description.
M.__has_description = function(option)
    return type(option) == "table" and Utils.table_has_key(option, "description") 
end

M.__ansibledoc_top_options =  function(options, depth, result)
    local inserted_description = false

    local sorted_keys = Utils.table_get_sorted_keys(options)

    -- Hack to iterate over a "sorted" table. 
    for _, attr in ipairs(sorted_keys) do
        local value = options[attr]

        local str_attr = attr
        local str_value = value

        -- Colorize the attribute dependeing on the option "required" inside value
        str_attr = M.__colorize_option(attr, value)

          -- First, we insert the attribute name and its description.
        if M.__has_description(value) then
            if type(value["description"]) == "table" then
                str_value = table.concat(value["description"])
            else
                str_value = vim.fn.string(value["description"])
            end
            -- Insert description appropiately
            table.insert(result, string.rep("\t", depth) .. str_attr.. ": " .. str_value)
        end

        -- Then if the value is a table let's create the suboptions
        if type(value) == "table" then
            M.__ansibledoc_sub_options(value, depth + 1, result)
        end

    end
end

M.__ansibledoc_sub_options = function(options, depth, result)
    

    -- Hack to iterate over a "sorted" table. 
    local sorted_keys = Utils.table_get_sorted_keys(options)

    local should_insert_default = not Utils.table_has_key(options, "default") and not Utils.table_has_key(options, "required")

    for _, attr in ipairs(sorted_keys) do
        local value = options[attr]

        local str_attr = attr
        local str_value = value
        local is_top_option = false
        local top_opt = {}

        -- Colorize the value dependeing on the option "required"
        str_attr = M.__colorize_option(attr, value)

        -- If it is considered top option, marked as such.
        if M.__has_description(value) then
            top_opt[attr]= value
            is_top_option = true
        end

        -- The `default` attribute is automatically added in ansible-doc
        -- but only on non-required attributes.
        if should_insert_default then
            local str_attr = M.__colorize_option("default", "null")
            table.insert(result, string.rep("\t", depth) .. str_attr.. ": null")
            should_insert_default = false
        end

        -- We never want to insert the description as it is part of a top option.
        -- And we also want to be able to ignore options.
        if attr ~= "description" and 
            not vim.tbl_contains(ignore_options, attr) and
            not is_top_option 
            then
            if type(value) == "table" then
                if vim.islist(value) and vim.isarray(value) then
                    str_value = vim.fn.string(value)
                    table.insert(result, string.rep("\t", depth) .. str_attr.. ": " .. str_value)
                else
                    str_value = table.concat(value)
                    table.insert(result, string.rep("\t", depth) .. str_attr.. ": " .. str_value)
                    M.__ansibledoc_sub_options(value, depth + 1, result)
                end
            else 
                str_value = vim.fn.string(value)
                table.insert(result, string.rep("\t", depth) .. str_attr .. ": " .. str_value .. "")
            end
        -- Genereate the top options
        elseif  is_top_option then 
            M.__ansibledoc_top_options(top_opt, depth, result)
        end

    end
    -- Insert new line
    table.insert(result,"")
end


local ansibledoc_enum = {
    a = M.ansibledoc_author,
    r = M.ansibledoc_return,
    t = M.ansibledoc_attributes,
    n = M.ansibledoc_notes,
    o = M.ansibledoc_options,
}

local ansibledoc_enum_list = {
    author = M.ansibledoc_author,
    ret = M.ansibledoc_return,
    attributes = M.ansibledoc_attributes,
    notes = M.ansibledoc_notes,
    options = M.ansibledoc_options,
}

M.ansibledoc_data = function(str_data, modules_order)

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

    M.ansibledoc_author(author, result)
    M.ansibledoc_options(options, result)
    M.ansibledoc_return(ret, result)
    M.ansibledoc_examples(examples, result)
    M.ansibledoc_attributes(attributes, result)
    M.ansibledoc_notes(notes, result)

    return result
end

return M
