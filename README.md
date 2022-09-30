# actions-preview.nvim

<https://user-images.githubusercontent.com/2226696/193223264-d4ea9140-d53b-4660-a8e6-0e9ee2597c51.mp4>

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
  -- options for telescope.nvim: https://github.com/nvim-telescope/telescope.nvim#themes
  telescope = require("telescope.themes").get_dropdown(),
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

## Acknowledgements

- [weilbith/nvim-code-action-menu](https://github.com/weilbith/nvim-code-action-menu) for idea.

## LICENSE

This project itself is distributed under [GPLv3].
However, this project includes the [neovim] code, which is distributed under the [Apache License 2.0].

[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.html
[Apache License 2.0]: https://www.apache.org/licenses/LICENSE-2.0
[neovim]: https://github.com/neovim/neovim/tree/master/runtime/lua/vim
