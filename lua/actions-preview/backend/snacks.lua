local M = {}

--- function called to preview item
--- taken from minipick backend
---@type snacks.picker.preview
local preview = function(ctx)
  local item = ctx.item
  local buf_id = ctx.preview:scratch()
  item.action:preview(function(preview)
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
  ---@type snacks.picker.finder.Item[]
  local items = {}
  for _, action in ipairs(actions) do
    local item = { text = action:title(), action = action }
    table.insert(items, item)
  end
  return items
end

---@type snacks.picker.Config
local basic_snacks_opts = {
  title = "Code Actions",
  items = {},
  format = "text",
  preview = preview,
  confirm = confirm
}

function M.is_supported()
  local ok, _ = pcall(require, "snacks.picker")
  return ok
end

function M.select(config, actions)
  local opts = vim.tbl_deep_extend('force', basic_snacks_opts, config or {})
  opts.items = actions_to_items(actions)
  require("snacks.picker").pick(nil, opts)
end

return M
