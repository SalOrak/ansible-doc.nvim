local _log = require("plenary.log")

local Const = require('ansible-doc.constants')
local File = require('ansible-doc.file')
local Parse = require('ansible-doc.parse')
local Module = require('ansible-doc.module')

local M = {
    docs = {},
}


---@brief Generates an error message based on parameters for
--- better errors during testing.
---
---@param module string: Module name where the error occurred.
---@param step string: The function or step on which the error occurred.
---@param err_msg string: Error message coming from the `pcall` function of @step
---
---@returns string.
local parse_error= function(module, step, err_msg)
    return {
        "From parsing [",
        module,
        "] during ",
        step,
        " got error: ",
        err_msg,
        "\n"
    }
end

---@brief Tests if the documentation of a module is properly 
--- generated and it does not throw any errors. 
--- If an error is thrown, the function returns early.
---
---@param module string: Name of the module to be tested.
---
---@returns table: 
---     status boolean: Whether the testing was successfull or not.
---     data   string:  Information about the error. `nil` in case of success.
M.single_module = function(module)

    if vim.tbl_isempty(M.docs) then
        M.docs = Module.generate_names_list()
    end

    local is_correct, err_msg = pcall(Module.get_raw_ansibledoc, module)
    if not is_correct then
        local err_msg = parse_error(module, "Module.get_raw_ansibledoc()", err_msg)
        return { status = false, data = err_msg}
    end

    local raw_data = err_msg

    local is_correct, err_msg = pcall(Parse.ansibledoc_data, raw_data)
    if not is_correct then
        local err_msg = parse_error(module, "Parse.ansibledoc_data()", err_msg)
        return { status = false, data = err_msg}
    end

    return { status= true, data = nil }
end


---@brief: Tests against all modules.
---
---   -- Note: Be careful as this will take some time to execute, as 
---   it must process data from all modules.
---
---   In case of an error, it is inserted at file `Const.errors_path` and 
---   the function continues executing.
---
---@returns nil
M.all_modules= function()
    if vim.tbl_isempty(M.docs) then
        M.docs = Module.generate_names_list()
    end

    File.writeFileAsync(Const.errors_path, "") -- Overwrite it with nothing

    local keys = vim.fn.keys(M.docs)
    local total = #keys
    local curr = 0
    local errors = 0
    local function step()
        curr = curr + 1
        module = keys[curr]

        vim.api.nvim_echo({{string.format("Testing progress: %d / %d", curr, total)}, {''}}, false, {})

        local test_data = M.single_module(module)
        if not test_data.status then
            errors = errors + 1
            File.appendFileAsync(Const.errors_path, test_data.data)
        end

        if curr < total then
            vim.defer_fn(step, 10) -- next in 10 ms
        else
            if errors > 0 then
                vim.api.nvim_echo({{string.format("Found %d errors.\n", errors)}, {string.format("Open an issue on GitHub (https://github.com/SalOrak/ansible-doc.nvim.git) showing the contents of the file at %s", Const.errors_path)}}, false, {})
            else
                vim.api.nvim_echo({{"Done. No errors found"}, {""}}, false, {})
            end
        end
    end
    step()
end

return M
