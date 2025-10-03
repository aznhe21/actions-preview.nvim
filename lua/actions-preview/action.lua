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
    pseudo_args = "--code-actions",
  }, opts or {})

  local lines = {}
  for _, change in ipairs(self.changes) do
    -- imitate git diff
    if change.kind == "rename" then
      table.insert(lines, string.format("diff %s a/%s b/%s", opts.pseudo_args, change.old_path, change.new_path))
      table.insert(lines, string.format("rename from %s", change.old_path))
      table.insert(lines, string.format("rename to %s", change.new_path))
      table.insert(lines, "")
    elseif change.kind == "create" then
      table.insert(lines, string.format("diff %s a/%s b/%s", opts.pseudo_args, change.path, change.path))
      -- delta needs file mode
      table.insert(lines, "new file mode 100644")
      -- diff-so-fancy needs index
      table.insert(lines, "index 0000000..fffffff")
      table.insert(lines, "")
    elseif change.kind == "delete" then
      table.insert(lines, string.format("diff %s a/%s b/%s", opts.pseudo_args, change.path, change.path))
      table.insert(lines, string.format("--- a/%s", change.path))
      table.insert(lines, "+++ /dev/null")
      table.insert(lines, "")
    elseif change.kind == "edit" then
      local text = vim.diff(table.concat(change.old, "\n") .. "\n", table.concat(change.new, "\n") .. "\n", config.diff)

      table.insert(lines, string.format("diff %s a/%s b/%s", opts.pseudo_args, change.path, change.path))
      table.insert(lines, string.format("--- a/%s", change.path))
      table.insert(lines, string.format("+++ b/%s", change.path))
      for line in vim.gsplit(vim.trim(text), "\n", true) do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    end
  end
  return lines
end

local function get_lines(bufnr)
  vim.fn.bufload(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function apply_text_edits(text_edits, lines, offset_encoding)
  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
  vim.lsp.util.apply_text_edits(text_edits, temp_buf, offset_encoding)
  local new_lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, false)
  vim.api.nvim_buf_delete(temp_buf, { force = true })
  return new_lines
end

local function edit_buffer_lines(text_edits, bufnr, offset_encoding)
  local lines = get_lines(bufnr)
  local new_lines = apply_text_edits(text_edits, lines, offset_encoding)
  return lines, new_lines
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
        local old, new = edit_buffer_lines(change.edits, bufnr, offset_encoding)

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
      local old, new = edit_buffer_lines(edits, bufnr, offset_encoding)

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

function Action.new(context, action)
  local resolved = action
  local client = assert(vim.lsp.get_client_by_id(context.client_id))
  local bufnr = assert(context.bufnr, "Must have buffer number")

  local supports_resolve
  if client.dynamic_capabilities then
    local reg = client.dynamic_capabilities:get("textDocument/codeAction", { bufnr = bufnr })

    supports_resolve = vim.tbl_get(reg or {}, "registerOptions", "resolveProvider")
      or client.supports_method("codeAction/resolve")
  else
    supports_resolve = type(client.server_capabilities.codeActionProvider) == "table"
      and client.server_capabilities.codeActionProvider.resolveProvider
  end

  if not action.edit and client and supports_resolve then
    -- needs to be resolved
    resolved = nil
  end

  return setmetatable({
    context = context,
    action = action,
    resolved = resolved,
    previewed = nil,
  }, { __index = Action })
end

function Action:client_name()
  local client = vim.lsp.get_client_by_id(self.context.client_id)
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

  local client = vim.lsp.get_client_by_id(self.context.client_id)
  client.request("codeAction/resolve", self.action, function(err, resolved_action)
    if err then
      if not self.action.command then
        vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
      end
      self.resolved = self.action
    else
      self.resolved = resolved_action or self.action
    end
    callback(self.resolved)
  end, self.context.bufnr)
end

function Action:preview(callback)
  if self.previewed then
    callback(self.previewed)
    return
  end

  self:resolve(function(action)
    local client = vim.lsp.get_client_by_id(self.context.client_id)

    local changes = action.edit and get_changes(action.edit, client.offset_encoding)
    if changes then
      local hl_cmd = config.get_highlight_command()
      self.previewed = hl_cmd and {
        cmdline = hl_cmd.make_cmdline(changes),
      } or {
        syntax = "diff",
        lines = changes:diff(),
      }
    elseif action.command then
      local command = type(action.command) == "table" and action.command or action
      self.previewed = {
        syntax = "",
        lines = {
          string.format("Preview is not available for this action (command=%s).", command.command),
          string.format("This is due to limitations of your language server (%s) implementation.", self:client_name()),
        },
      }
    end

    callback(self.previewed)
  end)
end

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/buf.lua#L506-L529
function Action:apply()
  self:resolve(function(action)
    local client = vim.lsp.get_client_by_id(self.context.client_id)

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
