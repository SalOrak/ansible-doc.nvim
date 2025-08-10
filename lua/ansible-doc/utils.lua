local M ={}

---@brief Returns true when the key is not nil in the table.
--- The tricky part is that a table can have a key but it is nil, but hey the key exists.
--- The "normal" way to do it would be to itereate over the keys and check if the key exists.
--- But, I want the key to EXIST and NOT BE NIL. Thus, the function
---
---@param t table: Table to check against.
---@param k string: Key used to check if `t` table contains it.
---
---@return boolean: Represents whether table contains an specific key with non-null value.
M.table_has_key = function(t, k)
    if type(t) ~= "table" then
        return false
    end

    if t[k] ~= nil then
        return true
    end

    return false
end


---@brief Tables are not usually expected to be ordered.
--- This makes it up for it. As we can't sort a table, we can sort the keys
--- inside of that table and iterate the table using the SORTED KEYS.
---
---@param t table: Table to get its keys sorted out.
---
---@return table: The "list" of keys 
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


