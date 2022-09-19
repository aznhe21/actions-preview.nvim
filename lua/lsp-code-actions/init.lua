local config = require("lsp-code-actions.config")
local Action = require("lsp-code-actions.action").Action

local actions = require("telescope.actions")
local state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local M = {}

local function on_code_action_results(results, ctx)
  local acts = {}
  for client_id, result in pairs(results) do
    for _, action in pairs(result.result or {}) do
      table.insert(acts, Action.new(ctx, client_id, action))
    end
  end
  if #acts == 0 then
    vim.notify("No code actions available", vim.log.levels.INFO)
    return
  end

  local opts = vim.deepcopy(config.telescope)
  if not opts then
    opts = require("telescope.themes").get_dropdown()
  end
  pickers
    .new(opts, {
      prompt_title = "Code actions:",
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

local function code_action_request(params)
  local bufnr = vim.api.nvim_get_current_buf()
  local method = "textDocument/codeAction"
  vim.lsp.buf_request_all(bufnr, method, params, function(results)
    on_code_action_results(results, { bufnr = bufnr, method = method, params = params })
  end)
end

function M.setup(opts)
  config.setup(opts)
end

function M.code_actions(context)
  vim.validate({ context = { context, "t", true } })
  context = context or {}
  if not context.diagnostics then
    local bufnr = vim.api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params = vim.lsp.util.make_range_params()
  params.context = context
  code_action_request(params)
end

function M.range_code_actions(context, start_pos, end_pos)
  vim.validate({ context = { context, "t", true } })
  context = context or {}
  if not context.diagnostics then
    local bufnr = vim.api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params = vim.lsp.util.make_given_range_params(start_pos, end_pos)
  params.context = context
  code_action_request(params)
end

return M
