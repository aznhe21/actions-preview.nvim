local M = {}

function M.is_supported()
  local ok, _ = pcall(require, "nui.menu")
  return ok
end

function M.select(config, actions)
  local Layout = require("nui.layout")
  local Menu = require("nui.menu")
  local Popup = require("nui.popup")
  local event = require("nui.utils.autocmd").event

  local nui_preview = Popup(vim.tbl_deep_extend("force", config.preview, {
    size = nil,
    border = {
      text = {
        top = "Code Action Preview",
      },
    },
  }))

  local nui_select = Menu(
    vim.tbl_deep_extend("force", config.select, {
      position = 0,
      size = nil,
      border = {
        text = {
          top = "Code Actions",
        },
      },
    }),
    {
      lines = vim.tbl_map(function(action)
        return Menu.item(action:title(), { action = action })
      end, actions),
      keymap = config.keymap,
      on_change = function(item)
        item.action:preview(function(preview)
          if nui_preview.bufnr == nil then
            return
          end

          preview = preview or { syntax = "", text = "preview not available" }

          vim.api.nvim_buf_set_lines(nui_preview.bufnr, 0, -1, false, vim.split(preview.text, "\n", true))
          vim.api.nvim_buf_set_option(nui_preview.bufnr, "syntax", preview.syntax)
        end)
      end,
      on_submit = function(item)
        item.action:apply()
      end,
    }
  )

  local layout = Layout(
    config.layout,
    Layout.Box({
      Layout.Box(nui_preview, { size = config.preview.size }),
      Layout.Box(nui_select, { size = config.select.size }),
    }, { dir = config.dir })
  )

  layout:mount()
  nui_select:on(event.BufLeave, function()
    nui_preview:unmount()
    nui_select:unmount()
  end)
end

return M
