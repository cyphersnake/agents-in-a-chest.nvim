-- Example keymaps for llm-legion.nvim
-- Add this file to your config and require it, or copy lines below.

vim.keymap.set('n', '<leader>lc', ':LLMSession claude --name session<CR>', { desc = 'LLM: Claude session' })
vim.keymap.set('n', '<leader>lx', ':LLMSession codex  --name fix-bug-123<CR>', { desc = 'LLM: Codex session' })
