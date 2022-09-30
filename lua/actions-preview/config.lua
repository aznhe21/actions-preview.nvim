local default_config = {
  backend = { "telescope" },
  telescope = nil,
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
