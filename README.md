# llm-legion.nvim

> [!WARNING]
> **⚠️ Unstable - Early Development**
> 
> This plugin is in active development and has not been extensively tested in production environments. 
> While core functionality works, you may encounter bugs or breaking changes. Use at your own risk and 
> please report any issues you find!

<div align="center">

**Launch LLM coding agents in isolated Git worktrees**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=flat-square&logo=lua)](http://www.lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Codeberg](https://img.shields.io/badge/Codeberg-2185D0?style=flat-square&logo=codeberg&logoColor=white)](https://codeberg.org/cyphersnake/llm-legion.nvim)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Configuration](#configuration) • [Contributing](#contributing)

</div>

## ✨ Features

`llm-legion.nvim` provides a sandboxed environment for LLM coding agents (Claude, Codex, etc.) to work on your codebase without affecting your main working tree:

- 🎯 **Isolated Worktrees** - Each LLM session runs in its own Git worktree outside your repository
- 🔄 **Auto-commit on Exit** - Changes are automatically committed when the session ends
- 🌳 **Branch Preservation** - Worktree is removed but branches remain for easy merging
- 📑 **Tab-based Sessions** - Each session opens in a new Neovim tab with terminal
- 🚀 **Concurrent Sessions** - Run multiple LLM agents simultaneously without conflicts
- 🧹 **Smart Cleanup** - Automatic cleanup of worktrees with orphan detection

## 🎬 Demo

```vim
:LLMSession claude --name refactor-auth
" Opens new tab with Claude in isolated worktree
" Work happens in .myrepo-worktrees/myrepo-abc1234/20250110-143022-5fa3c-refactor-auth/
" On exit: commits changes, removes worktree, keeps branch llm/claude/20250110-143022-5fa3c-refactor-auth
```

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "cyphersnake/llm-legion.nvim",
  url = "https://codeberg.org/cyphersnake/llm-legion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for tests only
  },
  cmd = { "LLMSession", "LLMAbort", "LLMCleanup" }, -- Load plugin when these commands are used
  config = function()
    require("llm_legion").setup({
      -- your configuration
    })
  end,
  keys = {
    { "<leader>lc", "<cmd>LLMSession claude --name session<cr>", desc = "Claude session" },
    { "<leader>lx", "<cmd>LLMSession codex --name session<cr>", desc = "Codex session" },
    { "<leader>la", "<cmd>LLMAbort<cr>", desc = "Abort LLM session" },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "cyphersnake/llm-legion.nvim",
  config = function()
    require("llm_legion").setup({})
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'https://codeberg.org/cyphersnake/llm-legion.nvim'
```

## 🚀 Usage

### Basic Commands

```vim
" Start a new LLM session
:LLMSession claude --name implement-feature

" Start from specific branch/commit
:LLMSession codex --name fix-bug --base develop

" Abort current session (auto-commits and cleans up)
:LLMAbort

" Clean up orphaned worktrees
:LLMCleanup
```

### Workflow Example

1. **Start a session** with your preferred LLM:
   ```vim
   :LLMSession claude --name add-tests
   ```

2. **The plugin automatically**:
   - Creates worktree at `../.myrepo-worktrees/myrepo-7fa3c4d/20250110-143022-5fa3c-add-tests/`
   - Creates branch `llm/claude/20250110-143022-5fa3c-add-tests`
   - Opens new tab with terminal running `claude`

3. **Work with the LLM** in the isolated environment

4. **On exit** (or `:LLMAbort`):
  - Auto-commits changes with message: `wip(llm-legion): claude/add-tests @ 2025-01-10T14:35:22Z [20250110-143022-5fa3c]`
   - Removes worktree directory
   - Preserves branch for review/merge

5. **Review and merge**:
   ```bash
   git log llm/claude/20250110-143022-5fa3c-add-tests
   git merge llm/claude/20250110-143022-5fa3c-add-tests
   ```

## ⚙️ Configuration

```lua
require("llm_legion").setup({
  -- Custom worktree location (default: auto-computed)
  worktrees_root = nil,
  
  -- Prefix for worktree directory name (default: repo name)
  worktrees_prefix = nil,
  
  -- Default base ref for new worktrees
  default_base = "HEAD",
  
  -- Provider configurations
  providers = {
    claude = { 
      cmd = "claude",
      args = {} 
    },
    codex = { 
      cmd = "codex",
      args = {} 
    },
    -- Add your own providers
    aider = {
      cmd = "aider",
      args = { "--yes-always" }
    },
  },
})
```

### Advanced Configuration Examples

<details>
<summary>Custom provider with environment variables</summary>

```lua
providers = {
  gpt4 = {
    cmd = "gpt4-cli",
    args = { "--model", "gpt-4-turbo" },
    -- Note: env vars should be set externally
  }
}
```
</details>

<details>
<summary>Custom worktree location</summary>

```lua
-- Place all worktrees in /tmp for ephemeral sessions
worktrees_root = "/tmp/llm-sessions",

-- Or use a custom prefix
worktrees_prefix = "ai-sandbox",
```
</details>

## 📝 Requirements

- **Neovim** ≥ 0.10
- **Git** with worktree support
- **LLM CLI tools** installed and authenticated:
  - [Claude CLI](https://docs.anthropic.com/claude/docs/claude-cli)
  - [Codex](https://github.com/microsoft/codex)
  - Or any terminal-based LLM interface

## 🧪 Testing

```bash
# Run tests with make
make test

# Run with custom Plenary location
make test PLENARY=~/.local/share/nvim/lazy/plenary.nvim

# Run manually
nvim --headless -u tests/minimal.vim \
  -c "PlenaryBustedDirectory tests/" -c qa
```

## 🗺️ Roadmap

- [ ] **Session Management**
  - [ ] List active sessions (`:LLMList`)
  - [ ] Switch between sessions (`:LLMSwitch`)
  - [ ] Session history and replay

- [ ] **Enhanced Providers**
  - [ ] Provider templates for common LLMs
  - [ ] Auto-detection of installed CLIs
  - [ ] Provider-specific configurations

- [ ] **Workflow Improvements**
  - [ ] Custom commit message templates
  - [ ] Pre/post session hooks
  - [ ] Integration with diffview.nvim
  - [ ] Auto-PR creation option

- [ ] **Safety & Recovery**
  - [ ] Session state persistence
  - [ ] Crash recovery
  - [ ] Undo last session

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `test:` Test additions or fixes
- `refactor:` Code refactoring
- `perf:` Performance improvements

## 📄 License

MIT - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the need for safe LLM code generation workflows
- Built with [Neovim](https://neovim.io)'s excellent Lua API
- Testing powered by [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## ⚠️ Security Notes

- Provider CLIs must be authenticated externally
- Worktrees are created with standard user permissions
- No sandboxing beyond Git worktree isolation
- Review LLM-generated commits before merging

## 💬 Support

- **Issues**: [Codeberg Issues](https://codeberg.org/cyphersnake/llm-legion.nvim/issues)
- **Mirror**: [GitHub Mirror](https://github.com/cyphersnake/llm-legion.nvim) (read-only)

---

<div align="center">
Made with ❤️ for the Neovim community
</div>
