local M = {}

local uv = vim.uv

M.writeFileAsync = function(path, data)
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

M.appendFileAsync = function(path, data)
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

M.readFileSync = function(path)
    local fd = assert(uv.fs_open(path, "r", 438))
    local stat = assert(uv.fs_fstat(fd))
    local data = assert(uv.fs_read(fd, stat.size, 0))
    assert(uv.fs_close(fd))
    return data
end

M.removeFile = function(path)
    local ok, err = os.remove(path)
    if not ok then
        P(err)
        return false
    end
    return true
end

return M
