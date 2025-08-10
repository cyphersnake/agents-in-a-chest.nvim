" Minimal, isolated test init: no user config
set nocompatible
set runtimepath^=.

lua << EOF
-- Try to locate plenary from common locations
local data = vim.fn.stdpath('data')
local candidates = {
  data .. '/lazy/plenary.nvim',
  data .. '/site/pack/packer/opt/plenary.nvim',
  'tests/vendor/plenary.nvim',
}
for _, p in ipairs(candidates) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:append(p)
  end
end

-- Load plugin under test
local ok, mod = pcall(require, 'llm_legion')
if ok then mod.setup({}) end

-- If Plenary isn’t available, print a clear message and exit
vim.schedule(function()
  if vim.fn.exists(':PlenaryBustedDirectory') ~= 2 then
    vim.api.nvim_err_writeln('[llm-legion tests] Plenary not found on rtp. Add tests/vendor/plenary.nvim or set PLENARY in Makefile.')
    vim.cmd('qa!')
  end
end)
EOF
