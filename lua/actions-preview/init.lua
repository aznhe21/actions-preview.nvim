local config = require("actions-preview.config")
local Action = require("actions-preview.action").Action

local actions = require("telescope.actions")
local state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local M = {}

---@private
---@return table {start={row, col}, end={row, col}} using (1, 0) indexing
local function range_from_selection()
  -- TODO: Use `vim.region()` instead https://github.com/neovim/neovim/pull/13896

  -- [bufnum, lnum, col, off]; both row and column 1-indexed
  local start = vim.fn.getpos('v')
  local end_ = vim.fn.getpos('.')
  local start_row = start[2]
  local start_col = start[3]
  local end_row = end_[2]
  local end_col = end_[3]

  -- A user can start visual selection at the end and move backwards
  -- Normalize the range to start < end
  if start_row == end_row and end_col < start_col then
    end_col, start_col = start_col, end_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end
  return {
    ['start'] = { start_row, start_col - 1 },
    ['end'] = { end_row, end_col - 1 },
  }
end

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

--- Selects a code action available at the current
--- cursor position.
---
---@param options table|nil Optional table which holds the following optional fields:
---  - context: (table|nil)
---      Corresponds to `CodeActionContext` of the LSP specification:
---        - diagnostics (table|nil):
---                      LSP `Diagnostic[]`. Inferred from the current
---                      position if not provided.
---        - only (table|nil):
---               List of LSP `CodeActionKind`s used to filter the code actions.
---               Most language servers support values like `refactor`
---               or `quickfix`.
---  - range: (table|nil)
---           Range for which code actions should be requested.
---           If in visual mode this defaults to the active selection.
---           Table must contain `start` and `end` keys with {row, col} tuples
---           using mark-like indexing. See |api-indexing|
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
function M.code_actions(options)
  vim.validate({ options = { options, "t", true } })
  options = options or {}
  local context = options.context or {}
  if not context.diagnostics then
    local bufnr = vim.api.nvim_get_current_buf()
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
  end
  local params
  local mode = vim.api.nvim_get_mode().mode
  if options.range then
    assert(type(options.range) == 'table', 'code_action range must be a table')
    local start = assert(options.range.start, 'range must have a `start` property')
    local end_ = assert(options.range['end'], 'range must have a `end` property')
    params = vim.lsp.util.make_given_range_params(start, end_)
  elseif mode == 'v' or mode == 'V' then
    local range = range_from_selection()
    params = vim.lsp.util.make_given_range_params(range.start, range['end'])
  else
    params = vim.lsp.util.make_range_params()
  end
  params.context = context
  code_action_request(params)
end

return M
