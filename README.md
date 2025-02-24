# actions-preview.nvim

<https://github.com/aznhe21/actions-preview.nvim/assets/2226696/fd927cdd-dce4-4741-98ec-3c40320ce624>

A neovim plugin that preview code with LSP code actions applied.

The following backends are available:
- [telescope.nvim]
- [mini.pick]
- [nui.nvim]
- [snacks.nvim]

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[mini.pick]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-pick.md
[nui.nvim]: https://github.com/MunifTanjim/nui.nvim
[snacks.nvim]: https://github.com/folke/snacks.nvim

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

  -- priority list of external command to highlight diff
  -- disabled by defalt, must be set by yourself
  highlight_command = {
    -- require("actions-preview.highlight").delta(),
    -- require("actions-preview.highlight").diff_so_fancy(),
    -- require("actions-preview.highlight").diff_highlight(),
  },

  -- priority list of preferred backend
  backend = { "telescope", "minipick", "snacks", "nui" },

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
    }
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

  --- options for snacks picker
  ---@type snacks.picker.Config
  snacks = {
    layout = { preset = "default" },
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

### `highlight_command`

![actions-preview-delta](https://github.com/aznhe21/actions-preview.nvim/assets/2226696/edf18d6b-fb3c-4cb9-9c46-ce689278dc75)

You can highlight diff with an external command by setting this item. This item
is a priority list, which searches for available commands from the top.

**NOTE for Windows users**: This feature only works with PowerShell and does not operate with cmd.exe.
Therefore, you need to setup your neovim to use PowerShell by following the instructions in [`:help shell-powershell`].

[`:help shell-powershell`]: https://neovim.io/doc/user/options.html#shell-powershell

```lua
local hl = require("actions-preview.highlight")
require("actions-preview").setup {
  highlight_command = {
    -- Highlight diff using delta: https://github.com/dandavison/delta
    -- The argument is optional, in which case "delta" is assumed to be
    -- specified.
    hl.delta("path/to/delta --option1 --option2"),
    -- You may need to specify "--no-gitconfig" since it is dependent on
    -- the gitconfig of the project by default.
    -- hl.delta("delta --no-gitconfig --side-by-side"),

    -- Highlight diff using diff-so-fancy: https://github.com/so-fancy/diff-so-fancy
    -- The arguments are optional, in which case ("diff-so-fancy", "less -R")
    -- is assumed to be specified. The existence of less is optional.
    hl.diff_so_fancy("path/to/diff-so-fancy --option1 --option2"),

    -- Highlight diff using diff-highlight included in git-contrib.
    -- The arguments are optional; the first argument is assumed to be
    -- "diff-highlight" and the second argument is assumed to be 
    -- `{ colordiff = "colordiff", pager = "less -R" }`. The existence of
    -- colordiff and less is optional.
    hl.diff_highlight(
      "path/to/diff-highlight",
      { colordiff = "path/to/colordiff" }
    ),

    -- And, you can use any command to highlight diff.
    -- Define the pipeline by `hl.commands`.
    hl.commands({
      { cmd = "command-to-diff-highlight" },
      -- `optional` can be used to define that the command is optional.
      { cmd = "less -R", optional = true },
    }),
    -- If you use optional `less -R` (or similar command), you can also use `hl.with_pager`.
    hl.with_pager("command-to-diff-highlight"),
    -- hl.with_pager("command-to-diff-highlight", "custom-pager"),

    -- Functions can also be specified for items. Functions are executed during setup.
    -- This is useful for `require(...)` at definition time, such as in lazy.nvim.
    function()
        return require("actions-preview.highlight").delta()
    end,
  },
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

### Why do I get `Preview is not available for this action` instead of a diff?

TL;DR: Because of implementation limitations in some language servers.
It is not possible to compute and display diffs in these language servers.

Unfortunately, some language servers realize Code Actions by means of [Command],
which can perform any operation, instead of [TextEdit], which notifies text changes.
In these language servers, we cannot get the result of text changes by a Code Action,
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
