local config = require("actions-preview.config")

local M = {}

local function get_lines(bufnr)
  vim.fn.bufload(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function get_eol(bufnr)
  local ff = vim.api.nvim_buf_get_option(bufnr, "fileformat")
  if ff == "dos" then
    return "\r\n"
  elseif ff == "unix" then
    return "\n"
  elseif ff == "mac" then
    return "\r"
  else
    error("invalid fileformat")
  end
end

local function apply_text_edits(text_edits, lines, offset_encoding)
  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
  vim.lsp.util.apply_text_edits(text_edits, temp_buf, offset_encoding)
  local new_lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, false)
  vim.api.nvim_buf_delete(temp_buf, { force = true })
  return new_lines
end

local function diff_text_edits(text_edits, bufnr, offset_encoding)
  local eol = get_eol(bufnr)

  local lines = get_lines(bufnr)
  local new_lines = apply_text_edits(text_edits, lines, offset_encoding)
  return vim.diff(table.concat(lines, eol) .. "\n", table.concat(new_lines, eol) .. "\n", config.diff)
end

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/util.lua#L492-L523
local function diff_text_document_edit(text_document_edit, offset_encoding)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)

  return diff_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/util.lua#L717-L756
local function diff_workspace_edit(workspace_edit, offset_encoding)
  local diff = ""
  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      -- imitate git diff
      if change.kind == "rename" then
        local old_path = vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":.")
        local new_path = vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":.")

        diff = diff .. string.format("diff --code-actions a/%s b/%s\n", old_path, new_path)
        diff = diff .. string.format("rename from %s\n", old_path)
        diff = diff .. string.format("rename to %s\n", new_path)
        diff = diff .. "\n"
      elseif change.kind == "create" then
        local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

        diff = diff .. string.format("diff --code-actions a/%s b/%s\n", path, path)
        diff = diff .. "new file\n"
        diff = diff .. "\n"
      elseif change.kind == "delete" then
        local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

        diff = diff .. string.format("diff --code-actions a/%s b/%s\n", path, path)
        diff = diff .. string.format("--- a/%s\n", path)
        diff = diff .. "+++ /dev/null\n"
        diff = diff .. "\n"
      elseif change.kind then
        -- do nothing
      else
        local path = vim.fn.fnamemodify(vim.uri_to_fname(change.textDocument.uri), ":.")

        diff = diff .. string.format("diff --code-actions a/%s b/%s\n", path, path)
        diff = diff .. string.format("--- a/%s\n", path)
        diff = diff .. string.format("+++ b/%s\n", path)
        diff = diff .. vim.trim(diff_text_document_edit(change, offset_encoding)) .. "\n"
        diff = diff .. "\n"
      end
    end

    return diff
  end

  local all_changes = workspace_edit.changes
  if all_changes and not vim.tbl_isempty(all_changes) then
    for uri, changes in pairs(all_changes) do
      local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
      local bufnr = vim.uri_to_bufnr(uri)

      diff = diff
        .. table.concat({
          string.format("diff --code-actions a/%s b/%s", path, path),
          string.format("--- a/%s", path),
          string.format("+++ b/%s", path),
          vim.trim(diff_text_edits(changes, bufnr, offset_encoding)),
          "",
          "",
        }, "\n")
    end
  end

  return diff
end

local Action = {}
M.Action = Action

function Action.new(context, client_id, action)
  local resolved = action
  local client = vim.lsp.get_client_by_id(client_id)
  if
    not action.edit
    and client
    and type(client.server_capabilities.codeActionProvider) == "table"
    and client.server_capabilities.codeActionProvider.resolveProvider
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

function Action:client_name()
  local client = vim.lsp.get_client_by_id(self.client_id)
  return client and client.name or ""
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

    local diff = action.edit and diff_workspace_edit(action.edit, client.offset_encoding)
    if diff ~= nil and diff ~= "" then
      self.previewed = {
        syntax = "diff",
        text = diff,
      }
      callback(self.previewed)
    elseif action.command then
      local command = type(action.command) == "table" and action.command or action
      self.previewed = {
        syntax = "",
        text = string.format(
          "Preview is not available for this action (command=%s).\n"
            .. "This is due to limitations of your language server (%s) implementation.",
          command.command,
          self:client_name()
        ),
      }
    end

    callback(self.previewed)
  end)
end

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/buf.lua#L506-L529
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
