local M = {}

--- function called to format item to list entry
---@param item snacks.picker.finder.Item
local function format(item)
  local ret = {} ---@type snacks.picker.Highlight[]

  local idx = ("%%%ds."):format(#tostring(item._count)):format(item.idx)
  ret[#ret + 1] = { idx, "SnacksPickerIdx" }

  ret[#ret + 1] = { " " }
  ret[#ret + 1] = { item.title }

  if item.client ~= "" then
    ret[#ret + 1] = { " " }
    ret[#ret + 1] = { ("[%s]"):format(item.client), "SnacksPickerSpecial" }
  end

  return ret
end

--- function called to preview item
--- taken from minipick backend
---@type snacks.picker.preview
local preview = function(ctx)
  local item = ctx.item
  local buf_id = ctx.preview:scratch()
  item.action:preview(function(preview)
    -- Add a check to ensure the buffer is still valid before operating on it
    if not vim.api.nvim_buf_is_valid(buf_id) then
      return
    end

    if preview and preview.cmdline then
      vim.api.nvim_buf_call(buf_id, function()
        vim.fn.termopen(preview.cmdline)
      end)
    else
      preview = preview or { syntax = "", lines = { "preview not available" } }

      vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, preview.lines)
      if preview.syntax ~= "" then
        vim.treesitter.start(buf_id, preview.syntax)
      else
        vim.api.nvim_set_option_value("syntax", preview.syntax, { buf = buf_id })
      end

      vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
    end
  end)
end

--- function called by picker when user selects item
---@type snacks.picker.Action.spec
local function confirm(picker, item)
  picker:close()
  item.action:apply()
end

--- map actions to snacks items
---@param actions table
---@return snacks.picker.finder.Item[]
local function actions_to_items(actions)
  local count = #actions
  local items = {} ---@type snacks.picker.finder.Item[]

  for idx, action in ipairs(actions) do
    local title = action:title()
    local client = action:client_name()

    table.insert(items, {
      -- make sure we can search by index or client name
      text = string.format("%d. %s %s", idx, title, client),
      idx = idx,
      title = title,
      client = client,
      action = action,
      -- used for adding padding to index in format function
      _count = count,
    })
  end

  return items
end

---@type snacks.picker.Config
local basic_snacks_opts = {
  title = "Code Actions",
  items = {},
  format = format,
  preview = preview,
  confirm = confirm,
}

function M.is_supported()
  local ok, _ = pcall(require, "snacks.picker")
  return ok
end

function M.select(config, actions)
  local opts = vim.tbl_deep_extend("force", basic_snacks_opts, config or {})
  opts.items = actions_to_items(actions)
  require("snacks.picker").pick(nil, opts)
end

return M
