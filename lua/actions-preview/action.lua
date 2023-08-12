local config = require("actions-preview.config")

local M = {}

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/util.lua#L106-L124
--- Convert UTF index to `encoding` index.
--- Convenience wrapper around vim.str_byteindex
---Alternative to vim.str_byteindex that takes an encoding.
---@param line string line to be indexed
---@param index number UTF index
---@param encoding string utf-8|utf-16|utf-32|nil defaults to utf-16
---@return number byte (utf-8) index of `encoding` index `index` in `line`
local function _str_byteindex_enc(line, index, encoding)
  if not encoding then
    encoding = "utf-16"
  end
  if encoding == "utf-8" then
    if index then
      return index
    else
      return #line
    end
  elseif encoding == "utf-16" then
    return vim.str_byteindex(line, index, true)
  elseif encoding == "utf-32" then
    return vim.str_byteindex(line, index)
  else
    error("Invalid encoding: " .. vim.inspect(encoding))
  end
end

local function get_lines(bufnr)
  vim.fn.bufload(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/util.lua#L277-L298
---@private
--- Position is a https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position
--- Returns a zero-indexed column, since set_lines() does the conversion to
---@param offset_encoding string utf-8|utf-16|utf-32
--- 1-indexed
local function get_line_byte_from_position(lines, position, offset_encoding)
  -- LSP's line and characters are 0-indexed
  -- Vim's line and columns are 1-indexed
  local col = position.character
  -- When on the first character, we can ignore the difference between byte and
  -- character
  if col > 0 then
    local line = lines[position.line + 1] or ""
    local ok, result
    ok, result = pcall(_str_byteindex_enc, line, col, offset_encoding)
    if ok then
      return result
    end
    return math.min(#line, col)
  end
  return col
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

-- based on https://github.com/neovim/neovim/blob/v0.7.2/runtime/lua/vim/lsp/util.lua#L336-L464
local function apply_text_edits(text_edits, lines, offset_encoding)
  -- Fix reversed range and indexing each text_edits
  local index = 0
  text_edits = vim.tbl_map(function(text_edit)
    index = index + 1
    text_edit._index = index

    if
      text_edit.range.start.line > text_edit.range["end"].line
      or text_edit.range.start.line == text_edit.range["end"].line
        and text_edit.range.start.character > text_edit.range["end"].character
    then
      local start = text_edit.range.start
      text_edit.range.start = text_edit.range["end"]
      text_edit.range["end"] = start
    end
    return text_edit
  end, text_edits)

  -- Sort text_edits
  table.sort(text_edits, function(a, b)
    if a.range.start.line ~= b.range.start.line then
      return a.range.start.line > b.range.start.line
    end
    if a.range.start.character ~= b.range.start.character then
      return a.range.start.character > b.range.start.character
    end
    if a._index ~= b._index then
      return a._index > b._index
    end
  end)

  -- Apply text edits.
  for _, text_edit in ipairs(text_edits) do
    -- Normalize line ending
    text_edit.newText, _ = string.gsub(text_edit.newText, "\r\n?", "\n")

    -- Convert from LSP style ranges to Neovim style ranges.
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(lines, text_edit.range.start, offset_encoding),
      end_row = text_edit.range["end"].line,
      end_col = get_line_byte_from_position(lines, text_edit.range["end"], offset_encoding),
      text = vim.split(text_edit.newText, "\n", true),
    }

    -- apply edits
    local before = (lines[e.start_row + 1] or ""):sub(1, e.start_col)
    local after = (lines[e.end_row + 1] or ""):sub(e.end_col + 1)
    for _ = e.start_row, e.end_row do
      table.remove(lines, e.start_row + 1)
    end
    for i, t in pairs(e.text) do
      if text_edit.insertTextFormat == 2 then
        t = vim.lsp.util.parse_snippet(t)
      end

      table.insert(lines, e.start_row + i, t)
    end
    lines[e.start_row + 1] = before .. lines[e.start_row + 1]
    lines[e.start_row + #e.text] = lines[e.start_row + #e.text] .. after
  end
end

local function diff_text_edits(text_edits, bufnr, offset_encoding)
  local eol = get_eol(bufnr)

  local lines = get_lines(bufnr)
  local old_text = table.concat(lines, eol)
  apply_text_edits(text_edits, lines, offset_encoding)

  return vim.diff(old_text .. "\n", table.concat(lines, eol) .. "\n", config.diff)
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
        text = string.format("Command: %s (%s)", command.title, command.command),
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
