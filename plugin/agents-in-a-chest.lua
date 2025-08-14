-- Autoload entry: define user commands and delegate to core module
local ok, mod = pcall(require, "agents_in_a_chest")
if not ok then
  vim.schedule(function()
    vim.notify("[agents-in-a-chest] failed to load core module", vim.log.levels.ERROR)
  end)
  return
end

-- Create commands
vim.api.nvim_create_user_command("AICSession", function(opts)
  -- Pass raw args split for now: first token is provider
  local args = {}
  if opts.args and #opts.args > 0 then
    for token in string.gmatch(opts.args, "[^%s]+") do
      table.insert(args, token)
    end
  end
  mod.session_cmd(args)
end, {
  nargs = "+",
  complete = function(arglead)
    return mod.complete_session(arglead)
  end,
  desc = "Start an AIC session",
})

vim.api.nvim_create_user_command("AICAbort", function()
  mod.abort_current()
end, {
  desc = "Abort current AIC session in tab (cleanup)",
})

vim.api.nvim_create_user_command("AICCleanup", function()
  mod.cleanup()
end, {
  desc = "Cleanup abandoned worktrees and prune git metadata",
})

vim.api.nvim_create_user_command("AICEnd", function()
  local fin = require('agents_in_a_chest.finalize')
  fin.end_session()
end, {
  desc = "End session and optionally land onto base via Neogit",
})
