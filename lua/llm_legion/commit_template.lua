local M = {}

local scheduled_by_repo = {}
local autocmd_set = false

local function is_buffer_empty_or_comments(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines == 0 then return true end
  local has_text = false
  for _, l in ipairs(lines) do
    local s = vim.trim(l)
    if s ~= '' and not vim.startswith(s, '#') then
      has_text = true
      break
    end
  end
  return not has_text
end

local function ensure_autocmd()
  if autocmd_set then return end
  autocmd_set = true
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'gitcommit',
    callback = function(args)
      local cwd = vim.fn.getcwd()
      local msg = scheduled_by_repo[cwd]
      if not msg or msg == '' then return end
      local buf = args.buf
      -- Only fill if buffer has no meaningful content yet
      if is_buffer_empty_or_comments(buf) then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { msg, '' })
        -- place cursor at end of first line
        pcall(vim.api.nvim_win_set_cursor, 0, { 1, #msg })
        -- mark as modified so Neogit/git sees the change
        vim.api.nvim_buf_set_option(buf, 'modified', true)
      end
      -- One-shot: clear the scheduled message for this repo
      scheduled_by_repo[cwd] = nil
    end,
  })
end

function M.schedule(repo_root, message)
  if not repo_root or repo_root == '' then return end
  if not message or message == '' then return end
  ensure_autocmd()
  scheduled_by_repo[repo_root] = message
end

return M

