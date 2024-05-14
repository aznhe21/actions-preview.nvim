local backend = require("actions-preview.backend")
local config = require("actions-preview.config")
local Action = require("actions-preview.action").Action

local M = {}

function M.setup(opts)
  config.setup(opts)
end

local old_select
---@param items {action: lsp.Command|lsp.CodeAction, ctx: lsp.HandlerContext}[]
local function ui_select_shim(items, opts, on_choice)
  if opts.kind == "codeaction" then
    local actions = {}
    for i, item in ipairs(items) do
      actions[i] = Action.new(item)
    end
    backend.select(config, actions, function(choice)
      choice.action = choice.resolved or choice.action
      on_choice(choice)
    end)
    return
  end

  old_select(items, opts, on_choice)
end

--- Selects a code action available at the current
--- cursor position.
---
---@param options? vim.lsp.buf.code_action.Opts
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
---@see vim.lsp.protocol.CodeActionTriggerKind
function M.code_actions(options)
  local _select = vim.ui.select
  if _select ~= ui_select_shim then
    old_select = _select
    vim.ui.select = ui_select_shim
  end
  vim.lsp.buf.code_action(options)
end

return M
