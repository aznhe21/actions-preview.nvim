local M = {}

function M.get_backend(config)
  local backends = config.backend
  if type(backends) ~= "table" then
    backends = { backends }
  end
  for _, backend in ipairs(backends) do
    local mod = vim.F.npcall(require, string.format("actions-preview.backend.%s", backend))
    if mod and mod.is_supported() then
      return mod, backend
    end
  end

  error("actions-preview: No backend available. Do you have any backend installed?")
end

function M.select(config, actions, on_choice)
  local mod, backend = M.get_backend(config)
  mod.select(config[backend], actions, on_choice)
end

return M
