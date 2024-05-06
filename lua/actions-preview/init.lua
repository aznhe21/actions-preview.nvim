local backend = require("actions-preview.backend")
local config = require("actions-preview.config")
local Action = require("actions-preview.action").Action

local M = {}

-- based on https://github.com/neovim/neovim/blob/v0.8.0/runtime/lua/vim/lsp/buf.lua#L153-L178
---@private
---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row, col}, end={row, col}} using (1, 0) indexing
local function range_from_selection(bufnr, mode)
  -- TODO: Use `vim.region()` instead https://github.com/neovim/neovim/pull/13896

  -- [bufnum, lnum, col, off]; both row and column 1-indexed
  local start = vim.fn.getpos("v")
  local end_ = vim.fn.getpos(".")
  local start_row = start[2]
  local start_col = start[3]
  local end_row = end_[2]
  local end_col = end_[3]

  -- A user can start visual selection at the end and move backwards
  -- Normalize the range to start < end
  if start_row == end_row and end_col < start_col then
    end_col, start_col = start_col, end_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  if mode == "V" then
    start_col = 1
    local lines = vim.api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)
    end_col = #lines[1]
  end

  return {
    ["start"] = { start_row, start_col - 1 },
    ["end"] = { end_row, end_col - 1 },
  }
end

local function on_code_action_results(results, ctx, options)
  local actions = {}
  for client_id, result in pairs(results) do
    for _, action in pairs(result.result or {}) do
      table.insert(actions, Action.new(ctx, client_id, action))
    end
  end
  if #actions == 0 then
    vim.notify("No code actions available", vim.log.levels.INFO)
    return
  end

  if options.apply and #actions == 1 then
    actions[1]:apply()
    return
  end
  backend.select(config, actions)
end

local function code_action_request(params, options)
  local bufnr = vim.api.nvim_get_current_buf()
  local method = "textDocument/codeAction"
  vim.lsp.buf_request_all(bufnr, method, params, function(results)
    on_code_action_results(results, { bufnr = bufnr, method = method, params = params }, options)
  end)
end

function M.setup(opts)
  config.setup(opts)
end

-- based on https://github.com/neovim/neovim/blob/v0.8.0/runtime/lua/vim/lsp/buf.lua#L890-L944
--- Selects a code action available at the current
--- cursor position.
---
---@param options table|nil Optional table which holds the following optional fields:
---  - context: (table|nil)
---      Corresponds to `CodeActionContext` of the LSP specification:
---        - diagnostics (table|nil):
---                      LSP `Diagnostic[]`. Inferred from the current
---                      position if not provided.
---        - only (table|nil):
---               List of LSP `CodeActionKind`s used to filter the code actions.
---               Most language servers support values like `refactor`
---               or `quickfix`.
---        - triggerKind (integer|nil):
---               The reason why code actions were requested.
---  - range: (table|nil)
---           Range for which code actions should be requested.
---           If in visual mode this defaults to the active selection.
---           Table must contain `start` and `end` keys with {row, col} tuples
---           using mark-like indexing. See |api-indexing|
---  - apply: (boolean|nil)
---           When set to `true`, and there is just one remaining action (after filtering),
---           the action is applied without user query.
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
function M.code_actions(options)
  vim.validate({ options = { options, "t", true } })
  options = options or {}
  local context = options.context or {}
  if not context.diagnostics then
    local bufnr = vim.api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params
  local mode = vim.api.nvim_get_mode().mode
  if options.range then
    assert(type(options.range) == "table", "code_action range must be a table")
    local start = assert(options.range.start, "range must have a `start` property")
    local end_ = assert(options.range["end"], "range must have a `end` property")
    params = vim.lsp.util.make_given_range_params(start, end_)
  elseif mode == "v" or mode == "V" then
    local range = range_from_selection(0, mode)
    params = vim.lsp.util.make_given_range_params(range.start, range["end"])
  else
    params = vim.lsp.util.make_range_params()
  end
  params.context = context
  code_action_request(params, options)
end

return M
