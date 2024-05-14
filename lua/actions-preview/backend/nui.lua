local M = {}

local job_is_running = function(job_id)
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.is_supported()
  local ok, _ = pcall(require, "nui.menu")
  return ok
end

function M.select(config, actions, on_choice)
  local Layout = require("nui.layout")
  local Menu = require("nui.menu")
  local Popup = require("nui.popup")

  local nui_preview = Popup(vim.tbl_deep_extend("force", config.preview, {
    size = nil,
    border = {
      text = {
        top = "Code Action Preview",
      },
    },
  }))
  local nui_select
  local caches = {}

  local focus_win = vim.api.nvim_get_current_win()
  local cleanup = function()
    for _, cache in pairs(caches) do
      if cache.term_id ~= nil and job_is_running(cache.term_id) then
        vim.fn.jobstop(cache.term_id)
      end
      if vim.api.nvim_buf_is_valid(cache.bufnr) then
        vim.api.nvim_buf_delete(cache.bufnr, { force = true })
      end
    end

    nui_preview:unmount()
    nui_select:unmount()

    if vim.api.nvim_win_is_valid(focus_win) then
      vim.api.nvim_set_current_win(focus_win)
    end
  end

  local lines = {}
  for idx, action in ipairs(actions) do
    table.insert(lines, Menu.item(action:title(), { index = idx, action = action }))
  end

  nui_select = Menu(
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
      lines = lines,
      keymap = config.keymap,
      on_change = function(item)
        local cache = caches[item.index]
        if cache then
          vim.api.nvim_win_set_buf(nui_preview.winid, cache.bufnr)
        else
          cache = {
            bufnr = vim.api.nvim_create_buf(false, true),
          }
          caches[item.index] = cache

          vim.api.nvim_win_set_buf(nui_preview.winid, cache.bufnr)

          item.action:preview(function(preview)
            if not vim.api.nvim_buf_is_valid(cache.bufnr) then
              return
            end

            if preview and preview.cmdline then
              vim.api.nvim_buf_call(cache.bufnr, function()
                cache.term_id = vim.fn.termopen(preview.cmdline)
              end)
            else
              preview = preview or { syntax = "", lines = { "preview not available" } }

              vim.api.nvim_buf_set_lines(cache.bufnr, 0, -1, false, preview.lines)
              if preview.syntax ~= "" then
                vim.treesitter.start(cache.bufnr, preview.syntax)
              else
                vim.api.nvim_buf_set_option(cache.bufnr, "syntax", preview.syntax)
              end
              vim.api.nvim_buf_set_option(cache.bufnr, "modifiable", false)
            end
          end)
        end
      end,
      on_submit = function(item)
        cleanup()
        on_choice(item.action)
      end,
      on_close = cleanup,
    }
  )

  local nui_layout = Layout(
    config.layout,
    Layout.Box({
      Layout.Box(nui_preview, { size = config.preview.size }),
      Layout.Box(nui_select, { size = config.select.size }),
    }, { dir = config.dir })
  )
  nui_layout:mount()
end

return M
