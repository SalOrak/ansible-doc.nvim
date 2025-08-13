-- @brief [[ Constant values that cannot be changed.
-- They are always the same and should stay the same. 
-- ]]

local Path = require('plenary.path')

local M = {
    data_path_exists = false,
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
    },
}

M.data_path = string.format("%s/ansible-doc", vim.fn.stdpath("data"))
M.ansible_modules_filepath = string.format("%s/modules.json", M.data_path)


M.ensure_data_path_exists = function()
    if M.data_path_exists then
        return
    end
    local path = Path:new(M.data_path)
    if not path:exists() then
        path:mkdir()
    end
    M.data_path_exists = true
end


return M
