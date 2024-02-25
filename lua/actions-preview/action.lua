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

local function edit_buffer_text(text_edits, bufnr, offset_encoding)
  return table.concat(lines, eol) .. eol, table.concat(new_lines, eol) .. eol
local function get_changes(workspace_edit, offset_encoding)
  local changes = {}
        table.insert(changes, {
          kind = "rename",
          old_path = old_path,
          new_path = new_path,
        })
        table.insert(changes, {
          kind = "create",
          path = path,
        })
        table.insert(changes, {
          kind = "delete",
          path = path,
        })
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
  elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
    for uri, edits in pairs(workspace_edit.changes) do
      local old, new = edit_buffer_text(edits, bufnr, offset_encoding)
      table.insert(changes, {
        kind = "edit",
        path = path,
        old = old,
        new = new,
      })
  return next(changes) and Changes.new(changes) or nil
    local changes = action.edit and get_changes(action.edit, client.offset_encoding)
    if changes then
      local hl_cmd = config.get_highlight_command()
      self.previewed = hl_cmd and {
        cmdline = hl_cmd.make_cmdline(changes),
      } or {
        text = changes:diff(),