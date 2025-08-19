# Ansible-doc (.) Neovim

`ansible-doc.nvim` offers a way to search through ansible documentation directly from the neovim editor.
Specifically, `ansible-doc` allows searching for ansible module's documentation using `fzf-lua`, previewing them and even customizing it!

## Usage

To use it you can either map the `AnsibleDoc` to a key or run it directly in Command mode.

Mapping example
```lua
vim.keymap.set({"n"}, "<leader>ad", ":AnsibleDoc<CR>")
```

## Demo

![Demo GIF](./assets/demo.gif)

## Dependencies

To install `ansible-doc.nvim`, first you must ensure you have the dependencies installed.

System dependencies are:
1. `ansible` must be installed and accessible.
2. `ansible-doc` must be installed and accessible.

Neovim dependencies are:
1. [`fzf-lua`](https://github.com/ibhagwan/fzf-lua)
2. [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)


## Installation

Using `Lazy`, the installation would look like this:

```lua
{
    "salorak/ansible-doc.nvim",
    dependencies = {
        'ibhagwan/fzf-lua',
        'nvim-lua/plenary.nvim'
    },
    opts = {
        -- ansible-doc configuration goes here. 
        -- See configuration section below.
    },
}
```

## Configuration

The following is the default configuration for `ansible-doc.nvim` plugin.
Passed to the `setup()` function when installing the plugin or use the `opts` spec in [Lazy](https://lazy.folke.io/spec#spec-setup).

```lua
--- @brief (Default) Configuration of ansible-doc plugin.
{

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
    -- Comment them out and move them to structure the documentation page as you please.
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

```


## Customization examples


## Why not use the ansible LSP? 

To be honest, I think they are 2 different tools. Whilst LSP allows for autocompletion of modules and real time documentation, among other goodies, `ansible-doc` enables the discovery of modules as well as buffer-based documentation.

But hey, its your editor, use what suits you best.

