local M = {}

local default_make_value = function(action)
  return {
    title = action:title(),
  }
end

local default_make_make_display = function(values)
  local entry_display = require("telescope.pickers.entry_display")
  local strings = require("plenary.strings")

  local index_width = 0
  local title_width = 0
  local client_width = 0
  for _, value in ipairs(values) do
    index_width = math.max(index_width, strings.strdisplaywidth(value.index))
    title_width = math.max(title_width, strings.strdisplaywidth(value.title))
    client_width = math.max(client_width, strings.strdisplaywidth(value.client_name))
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = index_width + 1 },
      { width = title_width },
      { width = client_width },
    },
  })
  return function(entry)
    return displayer({
      { entry.value.index .. ":", "TelescopePromptPrefix" },
      { entry.value.title },
      { entry.value.client_name, "TelescopeResultsComment" },
    })
  end
end

local job_is_running = function(job_id)
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function M.is_supported()
  local ok, _ = pcall(require, "telescope")
  return ok
end

function M.select(config, acts)
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local Previewer = require("telescope.previewers.previewer")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local utils = require("telescope.utils")

  local opts = vim.deepcopy(config) or require("telescope.themes").get_dropdown()

  local make_value = opts.make_value or default_make_value
  local values = {}
  for idx, act in ipairs(acts) do
    local value = make_value(act)
    if type(value) ~= "table" then
      error("'make_value' must return a table")
    end
    if value.title == nil then
      error("'make_value' must return a table containing a field 'title'")
    end

    table.insert(
      values,
      vim.tbl_extend(
        "force",
        {
          client_name = act:client_name(),
        },
        value,
        {
          index = idx,
          action = act,
        }
      )
    )
  end

  local make_display = (opts.make_make_display or default_make_make_display)(values)

  local buffers = {}
  local term_ids = {}

  pickers
    .new(opts, {
      prompt_title = "Code Actions",
      previewer = Previewer:new({
        title = "Code Action Preview",
        setup = function(_self)
          return {}
        end,
        teardown = function(self)
          self.state.winid = nil
          self.state.bufnr = nil

          for _, bufnr in ipairs(buffers) do
            local term_id = term_ids[bufnr]
            if term_id and job_is_running(term_id) then
              vim.fn.jobstop(term_id)
            end
            utils.buf_delete(bufnr)
          end

          buffers = {}
          term_ids = {}
        end,
        preview_fn = function(self, entry, status)
          local preview_winid = status.layout and status.layout.preview and status.layout.preview.winid
            or status.preview_win

          local do_preview = false
          local bufnr = buffers[entry.index]
          if not bufnr then
            bufnr = vim.api.nvim_create_buf(false, true)
            buffers[entry.index] = bufnr
            do_preview = true

            vim.api.nvim_win_set_option(preview_winid, "winhl", "Normal:TelescopePreviewNormal")
            vim.api.nvim_win_set_option(preview_winid, "signcolumn", "no")
            vim.api.nvim_win_set_option(preview_winid, "foldlevel", 100)
            vim.api.nvim_win_set_option(preview_winid, "wrap", false)
            vim.api.nvim_win_set_option(preview_winid, "scrollbind", false)
          end

          utils.win_set_buf_noautocmd(preview_winid, bufnr)
          self.state.winid = preview_winid
          self.state.bufnr = bufnr

          if do_preview then
            entry.value.action:preview(function(preview)
              if preview and preview.cmdline then
                vim.api.nvim_buf_call(bufnr, function()
                  term_ids[bufnr] = vim.fn.termopen(preview.cmdline)
                end)
              else
                preview = preview or { syntax = "", text = "preview not available" }

                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(preview.text, "\n", true))
                vim.api.nvim_buf_set_option(bufnr, "syntax", preview.syntax)
              end
            end)
          end
        end,
        scroll_fn = function(self, direction)
          if not self.state then
            return
          end

          local count = math.abs(direction)
          local term_id = term_ids[self.state.bufnr]
          if term_id and job_is_running(term_id) then
            local input = direction > 0 and "d" or "u"

            local termcode = vim.api.nvim_replace_termcodes(count .. input, true, false, true)
            vim.fn.chansend(term_id, termcode)
          else
            local input = direction > 0 and [[]] or [[]]

            vim.api.nvim_win_call(self.state.winid, function()
              vim.cmd([[normal! ]] .. count .. input)
            end)
          end
        end,
      }),
      finder = finders.new_table({
        results = values,
        entry_maker = function(value)
          return {
            display = make_display,
            ordinal = value.index .. value.title,
            value = value,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection then
            return
          end

          selection.value.action:apply()
        end)

        return true
      end,
    })
    :find()
end

return M
