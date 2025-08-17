
--- @brief (Default) Configuration of ansible-doc plugin.

local M = {

    -- Pre computes ALL ansible modules on first startup.
    -- Tradeoff between disk and CPU.
    pre_compute = {
        -- Enables precomputing ansible modules.
        enable = false,
        -- Whether to overwrite precomputing. It takes a long time.
        -- WARNING: Use it with caution and don't keep it enabled!
        overwrite = false
    },

    -- Whether the buffer list acts as a documentation page cache.
    -- When requesting a documentation already rendered and present in the
    -- buffer list, show it instead of rendering again.
    cache_pages = true,

    -- Buffer options 
    buffer_opts = {
        -- Options passed to nvim_create_buf directly
        -- see :help nvim_create_buf
        listed = true,
        scratch = true
    },

    -- Options to pass directly to `fzf-lua`
    fzf_opts = {
        prompt = "Ansible modules > ",
    },

    -- Configuration for sections presence and ordering
    -- The following is the complete list of options.
    -- Comment them out and move them to structure documentation as you please.
    docs_structure = {
        "author",
        "attributes",
        "examples",
        "notes",
        "options",
        "return",
    },

    -- Path to file containing errors when testing
    errors_path = "/tmp/ansible-doc.errors.txt",

}

return M
