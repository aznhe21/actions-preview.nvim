local default_config = {
  backend = { "telescope", "nui" },
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
end

return M
