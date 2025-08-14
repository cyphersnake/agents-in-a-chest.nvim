-- Example keymaps for agents-in-a-chest.nvim
-- Add this file to your config and require it, or copy lines below.

vim.keymap.set('n', '<leader>lc', ':AICSession claude --name session<CR>', { desc = 'AIC: Claude session' })
vim.keymap.set('n', '<leader>lx', ':AICSession codex  --name fix-bug-123<CR>', { desc = 'AIC: Codex session' })
