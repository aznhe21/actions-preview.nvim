# actions-preview.nvim

<https://github.com/aznhe21/actions-preview.nvim/assets/2226696/fd927cdd-dce4-4741-98ec-3c40320ce624>

A neovim plugin that preview code with LSP code actions applied.

The following backends are available:
- [telescope.nvim]
- [nui.nvim]

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[nui.nvim]: https://github.com/MunifTanjim/nui.nvim

## Installation

Using [packer.nvim]:
```lua
use {
  "aznhe21/actions-preview.nvim",
  config = function()
    vim.keymap.set({ "v", "n" }, "gf", require("actions-preview").code_actions)
  end,
}
```

[packer.nvim]: https://github.com/wbthomason/packer.nvim

## Configuration

You can customize preview using setup function if you need it.

Default configuration:
```lua
require("actions-preview").setup {
  -- options for vim.diff(): https://neovim.io/doc/user/lua.html#vim.diff()
  diff = {
    ctxlen = 3,
  },
  -- priority list of preferred backend
  backend = { "telescope", "nui" },

  -- options related to telescope.nvim
  telescope = vim.tbl_extend(
    "force",
    -- telescope theme: https://github.com/nvim-telescope/telescope.nvim#themes
    require("telescope.themes").get_dropdown(),
    -- a table for customizing content
    {
      -- a function to make a table containing the values to be displayed.
      -- fun(action: Action): { title: string, client_name: string|nil }
      make_value = nil,

      -- a function to make a function to be used in `display` of a entry.
      -- see also `:h telescope.make_entry` and `:h telescope.pickers.entry_display`.
      -- fun(values: { index: integer, action: Action, title: string, client_name: string }[]): function
      make_make_display = nil,
    },
  ),

  -- options for nui.nvim components
  nui = {
    -- component direction. "col" or "row"
    dir = "col",
    -- keymap for selection component: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/menu#keymap
    keymap = nil,
    -- options for nui Layout component: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/layout
    layout = {
      position = "50%",
      size = {
        width = "60%",
        height = "90%",
      },
      min_width = 40,
      min_height = 10,
      relative = "editor",
    },
    -- options for preview area: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup
    preview = {
      size = "60%",
      border = {
        style = "rounded",
        padding = { 0, 1 },
      },
    },
    -- options for selection area: https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/menu
    select = {
      size = "40%",
      border = {
        style = "rounded",
        padding = { 0, 1 },
      },
    },
  },
}
```

An example of customizing diff algorithms and telescope appearance.

```lua
require("actions-preview").setup {
  diff = {
    algorithm = "patience",
    ignore_whitespace = true,
  },
  telescope = require("telescope.themes").get_dropdown { winblend = 10 },
}
```

## FAQ

### How to make it look like README (above)?

Here is a config to reproduce the README.

```lua
require("actions-preview").setup {
  telescope = {
    sorting_strategy = "ascending",
    layout_strategy = "vertical",
    layout_config = {
      width = 0.8,
      height = 0.9,
      prompt_position = "top",
      preview_cutoff = 20,
      preview_height = function(_, _, max_lines)
        return max_lines - 15
      end,
    },
  },
}
```

### Why do I get `Command: ...` instead of a diff?

TL;DR: Because of implementation limitations in some Language Servers.
It is not possible to compute and display diffs in these Language Servers.

Unfortunately, some Language Servers realize Code Actions by means of [Command],
which can perform any operation, instead of [TextEdit], which notifies text changes.
In these Language Servers, we cannot get the result of text changes by a Code Action,
and as a result, we cannot compute and display diffs.

[TextEdit]: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textEdit
[Command]: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#command

## Acknowledgements

- [weilbith/nvim-code-action-menu](https://github.com/weilbith/nvim-code-action-menu) for idea.
- [nvim-telescope/telescope-ui-select.nvim](https://github.com/nvim-telescope/telescope-ui-select.nvim) for UI.

## LICENSE

This project itself is distributed under [GPLv3].
However, this project includes the [neovim] code, which is distributed under the [Apache License 2.0].

[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.html
[Apache License 2.0]: https://www.apache.org/licenses/LICENSE-2.0
[neovim]: https://github.com/neovim/neovim/tree/master/runtime/lua/vim
