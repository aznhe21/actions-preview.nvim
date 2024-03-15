local config = require("actions-preview.config")

local M = {}

local Changes = {}
M.Changes = Changes

function Changes.new(changes)
  return setmetatable({
    changes = changes,
  }, { __index = Changes })
end

function Changes:diff(opts)
  opts = vim.tbl_extend("force", {
    pseudo_args = "--git",
  }, opts or {})

  local diff = ""
  for _, change in ipairs(self.changes) do
    -- imitate git diff
    if change.kind == "rename" then
      diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.old_path, change.new_path)
      diff = diff .. string.format("rename from %s\n", change.old_path)
      diff = diff .. string.format("rename to %s\n", change.new_path)
      diff = diff .. "\n"
    elseif change.kind == "create" then
      diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
      -- delta needs file mode
      diff = diff .. "new file mode 100644\n"
      -- diff-so-fancy needs index
      diff = diff .. "index 0000000..fffffff\n"
      diff = diff .. "\n"
    elseif change.kind == "delete" then
      diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
      diff = diff .. string.format("--- a/%s\n", change.path)
      diff = diff .. "+++ /dev/null\n"
      diff = diff .. "\n"
    elseif change.kind == "edit" then
      diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
      diff = diff .. string.format("--- a/%s\n", change.path)
      diff = diff .. string.format("+++ b/%s\n", change.path)
      diff = diff .. vim.trim(vim.diff(change.old, change.new, config.diff)) .. "\n"
      diff = diff .. "\n"
    end
  end
  return diff
end

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

local function edit_buffer_text(text_edits, bufnr, offset_encoding)
  local eol = get_eol(bufnr)

  local lines = get_lines(bufnr)
  local new_lines = apply_text_edits(text_edits, lines, offset_encoding)
  return table.concat(lines, eol) .. eol, table.concat(new_lines, eol) .. eol
end

local function get_changes(workspace_edit, offset_encoding)
  local changes = {}

  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      if change.kind == "rename" then
        local old_path = vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":.")
        local new_path = vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":.")

        table.insert(changes, {
          kind = "rename",
          old_path = old_path,
          new_path = new_path,
        })
      elseif change.kind == "create" then
        local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

        table.insert(changes, {
          kind = "create",
          path = path,
        })
      elseif change.kind == "delete" then
        local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

        table.insert(changes, {
          kind = "delete",
          path = path,
        })
      elseif change.kind then
        -- do nothing
      else
        local uri = change.textDocument.uri
        local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
        local bufnr = vim.uri_to_bufnr(uri)
        local old, new = edit_buffer_text(change.edits, bufnr, offset_encoding)

        table.insert(changes, {
          kind = "edit",
          path = path,
          old = old,
          new = new,
        })
      end
    end
  elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
    for uri, edits in pairs(workspace_edit.changes) do
      local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
      local bufnr = vim.uri_to_bufnr(uri)
      local old, new = edit_buffer_text(edits, bufnr, offset_encoding)

      table.insert(changes, {
        kind = "edit",
        path = path,
        old = old,
        new = new,
      })
    end
  end

  return next(changes) and Changes.new(changes) or nil
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

    local changes = action.edit and get_changes(action.edit, client.offset_encoding)
    if changes then
      local hl_cmd = config.get_highlight_command()
      self.previewed = hl_cmd and {
        cmdline = hl_cmd.make_cmdline(changes),
      } or {
        syntax = "diff",
        text = changes:diff(),
      }
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
