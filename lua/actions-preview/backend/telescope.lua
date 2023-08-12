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

  pickers
    .new(opts, {
      prompt_title = "Code Actions",
      previewer = previewers.new_buffer_previewer({
        title = "Code Action Preview",
        define_preview = function(self, entry)
          entry.value.action:preview(function(preview)
            if self.state.bufnr == nil then
              return
            end

            preview = preview or { syntax = "", text = "preview not available" }

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(preview.text, "\n", true))
            vim.api.nvim_buf_set_option(self.state.bufnr, "syntax", preview.syntax)
          end)
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
