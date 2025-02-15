local M = {}

function M.is_supported()
  local ok, _ = pcall(require, "mini.pick")
  return ok
end

function M.select(_config, actions)
  local minipick = require("mini.pick")

  local preview_action = function(buf_id, item)
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

  local choose_action = function(item)
    item.action:apply()
  end

  local source = {
    name = "Code Actions",
    items = {},
    preview = preview_action,
    choose = choose_action,
  }

  for _, action in ipairs(actions) do
    table.insert(source.items, {
      text = action:title(),
      action = action,
    })
  end

  minipick.start({ source = source })
end

return M
