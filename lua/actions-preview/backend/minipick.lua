local M = {}

local job_is_running = function(job_id)
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.is_supported()
  local ok, _ = pcall(require, "mini.pick")
  return ok
end

function M.select(config, actions)
  local minipick = require("mini.pick")

  local buffers = {}
  local term_ids = {}

  local cleanup = function()
    for _, buf_id in ipairs(buffers) do
      local term_id = term_ids[buf_id]
      if term_id and job_is_running(term_id) then
        vim.fn.jobstop(term_id)
      end
      if vim.api.nvim_buf_is_valid(buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
      end
    end
  end

  local preview_action = function(buf_id, item)
    table.insert(buffers, buf_id)

    item.action:preview(function(preview)
      if preview and preview.cmdline then
        vim.api.nvim_buf_call(buf_id, function()
          term_ids[buf_id] = vim.pn.termopen(preview.cmdline)
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
    cleanup()
    item.action:apply()
  end

  local source = {
    name = "Code Actions",
    items = {},
    preview = preview_action,
    choose = choose_action,
  }

  for idx, action in ipairs(actions) do
    table.insert(source.items, {
      text = action:title(),
      idx = idx,
      action = action,
    })
  end

  minipick.start({ source = source })
end

return M
