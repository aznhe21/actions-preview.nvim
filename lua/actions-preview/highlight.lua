local M = {}

function M.commands(commands)
  return {
    is_available = function()
      for _, cmd in ipairs(commands) do
        if cmd.optional ~= true and vim.fn.executable(cmd.cmd:match("^%S+")) ~= 1 then
          return false
        end
      end
      return true
    end,
    make_cmdline = function(changes)
      local cmdline = string.format("echo %s", vim.fn.shellescape(changes:diff()))
      for _, cmd in ipairs(commands) do
        if vim.fn.executable(cmd.cmd:match("^%S+")) == 1 then
          cmdline = cmdline .. " | " .. cmd.cmd
        end
      end
      return cmdline
    end,
  }
end

function M.with_pager(cmd, pager)
  pager = pager or "less -R"
  return M.commands({ { cmd = cmd }, { cmd = pager, optional = true } })
end

function M.delta(cmd)
  cmd = cmd or "delta"
  return {
    is_available = function()
      return vim.fn.executable(cmd:match("^%S+")) == 1
    end,
    make_cmdline = function(changes)
      return string.format("echo %s | %s", vim.fn.shellescape(changes:diff({ pseudo_args = "--git" })), cmd)
    end,
  }
end

function M.diff_so_fancy(cmd, pager)
  cmd = cmd or "diff-so-fancy"
  return M.with_pager(cmd, pager)
end

function M.diff_highlight(cmd, opts)
  cmd = cmd or "diff-highlight"
  opts = opts or {}
  return M.commands({
    { cmd = opts.colordiff or "colordiff", optional = true },
    { cmd = cmd },
    { cmd = opts.pager or "less -R", optional = true },
  })
end

return M
