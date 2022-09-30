local M = {}

function M.is_supported()
  local ok, _ = pcall(require, "telescope")
  return ok
end

function M.select(config, acts)
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local previewers = require("telescope.previewers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local opts = vim.deepcopy(config) or require("telescope.themes").get_dropdown()
  pickers
    .new(opts, {
      prompt_title = "Code Actions",
      previewer = previewers.new_buffer_previewer({
        title = "Code Action Preview",
        define_preview = function(self, entry)
          entry.value:preview(function(preview)
            preview = preview or { syntax = "", text = "preview not available" }

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(preview.text, "\n", true))
            vim.api.nvim_buf_set_option(self.state.bufnr, "syntax", preview.syntax)
          end)
        end,
      }),
      finder = finders.new_table({
        results = acts,
        entry_maker = function(action)
          local title = action:title()
          return {
            display = title,
            ordinal = title,
            value = action,
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

          selection.value:apply()
        end)

        return true
      end,
    })
    :find()
end

return M
