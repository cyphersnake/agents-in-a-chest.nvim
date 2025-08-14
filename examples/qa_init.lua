-- Minimal, isolated init to run only this plugin + Neogit with Lazy

-- Keep your main config untouched by using NVIM_APPNAME when launching:
--   NVIM_APPNAME=agents-in-a-chest-qa nvim -u examples/qa_init.lua

-- Bootstrap lazy.nvim into this isolated profile
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic settings for a clean QA session
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true

-- When launching from the plugin repo root, let Lazy load the local dir
-- Resolve absolute plugin root from this file's location
local this = debug.getinfo(1, 'S').source
local this_path = this:sub(1, 1) == '@' and this:sub(2) or this
local plugin_root = vim.fn.fnamemodify(this_path, ':p:h:h') -- examples/ -> repo root

require('lazy').setup({
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      -- Optional but nice for diffs:
      -- 'sindrets/diffview.nvim',
      -- 'nvim-telescope/telescope.nvim',
    },
  },
  {
    dir = plugin_root,
    name = 'agents-in-a-chest.nvim',
    config = function()
      require('agents_in_a_chest').setup({
        landing = { auto_prompt = true }, -- base branch auto-detected (origin/HEAD → main/master → current)
      })
    end,
  },
}, {
  ui = { border = 'rounded' },
  checker = { enabled = false },
})

-- Handy mappings for quick QA
vim.keymap.set('n', '<leader>ls', ":AICSession claude --name qa<CR>", { desc = 'Start AIC session' })
vim.keymap.set('n', '<leader>le', ":AICEnd<CR>", { desc = 'End session (land via Neogit)' })
vim.keymap.set('n', '<leader>la', ":AICAbort<CR>", { desc = 'Abort session' })
vim.keymap.set('n', '<leader>lc', ":AICCleanup<CR>", { desc = 'Cleanup worktrees' })

-- Print a small banner so it’s obvious we’re in QA profile
vim.schedule(function()
  vim.notify('[agents-in-a-chest QA] Lazy profile active. Use :AICSession / :AICEnd', vim.log.levels.INFO)
end)
