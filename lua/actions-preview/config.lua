local default_config = {
  backend = { "telescope", "minipick", "nui" },
  telescope = nil,
  nui = {
    dir = "col",
    keymap = nil,
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
    preview = {
      size = "60%",
      border = {
        style = "rounded",
        padding = { 0, 1 },
      },
    },
    select = {
      size = "40%",
      border = {
        style = "rounded",
        padding = { 0, 1 },
      },
    },
  },
  diff = {
    ctxlen = 3,
  },
  highlight_command = {
    -- hl.delta(),
    -- hl.diff_so_fancy(),
    -- hl.diff_highlight(),
  },
}
local unmodifiable_config = {
  diff = {
    on_hunk = nil,
    result_type = nil,
  },
}

local M = vim.deepcopy(default_config)

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", default_config, opts or {}, unmodifiable_config)
  for k, v in pairs(config) do
    M[k] = v
  end

  for i, cmd in ipairs(M.highlight_command) do
    if type(cmd) == "function" then
      M.highlight_command[i] = cmd()
    end
  end
end

function M.get_highlight_command()
  for _, cmd in ipairs(M.highlight_command) do
    if cmd.is_available() then
      return cmd
    end
  end
end

return M
