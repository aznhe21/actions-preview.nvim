local util = require("lsp-code-actions.util")

local M = {}

local Action = {}
M.Action = Action

function Action.new(context, client_id, action)
  local resolved = action
  local client = vim.lsp.get_client_by_id(client_id)
  if
    not action.edit
    and client
    and type(client.resolved_capabilities.code_action) == "table"
    and client.resolved_capabilities.code_action.resolveProvider
  then
    -- needs to be resolved
    resolved = nil
  end

  return setmetatable({
    context = context,
    client_id = client_id,
    action = action,
    resolved = resolved,
    previewed = nil,
  }, { __index = Action })
end

function Action:title()
  local title = self.action.title:gsub("\r\n", "\\r\\n")
  return title:gsub("\n", "\\n")
end

function Action:resolve(callback)
  if self.resolved then
    callback(self.resolved)
    return
  end

  local client = vim.lsp.get_client_by_id(self.client_id)
  client.request("codeAction/resolve", self.action, function(err, resolved_action)
    if err then
      vim.notify(err.code .. ": " .. err.message, vim.log.levels.WARN)
      self.resolved = self.action
    else
      self.resolved = resolved_action
    end
    callback(self.resolved)
  end)
end

function Action:preview(callback)
  if self.previewed then
    callback(self.previewed)
    return
  end

  self:resolve(function(action)
    local client = vim.lsp.get_client_by_id(self.client_id)

    if action.edit then
      local diff = util.diff_workspace_edit(action.edit, client.offset_encoding)
      self.previewed = {
        syntax = "diff",
        text = diff,
      }
      callback(self.previewed)
    elseif action.command then
      local command = type(action.command) == "table" and action.command or action
      self.previewed = {
        syntax = "",
        text = string.format("Run command %s (%s)", command.title, command.command),
      }
    end

    callback(self.previewed)
  end)
end

function Action:apply()
  self:resolve(function(action)
    local client = vim.lsp.get_client_by_id(self.client_id)

    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    if action.command then
      local command = type(action.command) == "table" and action.command or action
      local fn = client.commands[command.command] or vim.lsp.commands[command.command]
      if fn then
        local enriched_ctx = vim.deepcopy(self.context)
        enriched_ctx.client_id = client.id
        fn(command, enriched_ctx)
      else
        -- Not using command directly to exclude extra properties,
        -- see https://github.com/python-lsp/python-lsp-server/issues/146
        local params = {
          command = command.command,
          arguments = command.arguments,
          workDoneToken = command.workDoneToken,
        }
        client.request("workspace/executeCommand", params, nil, self.context.bufnr)
      end
    end
  end)
end

return M
