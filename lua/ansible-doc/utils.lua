local M ={}

M.table_has_key = function(t, k)

    if type(t) ~= "table" then
        return false
    end

    if t[k] ~= nil then
        return true
    end

    return false
end

M.table_get_sorted_keys = function(t)
    if type(t) ~= "table" then
        return t
    end

    local tbl = {}
    local keys = vim.tbl_keys(t)
    table.sort(keys)

    return keys
end


return M


