<div align="center">

# agents-in-a-chest.nvim

<img src=".img/logo.png" alt="agents-in-a-chest logo" width="400">

**Launch LLM coding agents in isolated Git worktrees**

</div>

> [!WARNING]
> **⚠️ Unstable - Early Development**
> 
> This plugin is in active development and has not been extensively tested in production environments. 
> While core functionality works, you may encounter bugs or breaking changes. Use at your own risk and 
> please report any issues you find!

<div align="center">

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=flat-square&logo=lua)](http://www.lua.org)
[![MIT License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Codeberg](https://img.shields.io/badge/Codeberg-2185D0?style=flat-square&logo=codeberg&logoColor=white)](https://codeberg.org/cyphersnake/agents-in-a-chest.nvim)

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Configuration](#configuration) • [Contributing](#contributing)

</div>

## ✨ Features

A focused flow: create a few agents, close them, then cherry-pick their work back to your base branch.

- 🎯 **Isolated worktrees**: each agent runs in its own Git worktree
- 🚀 **Multiple agents**: start several sessions in parallel (one tab each)
- 🔄 **Auto-commit on exit**: closing the tab finalizes the session safely
- 🧭 **Cherry-pick landing**: use Neogit to land changes onto your base branch
- 🌳 **Branch provenance**: `aic/...` branches are preserved for review/audits
- 🧹 **Smart cleanup**: worktrees are cleaned; base branch is auto-stashed/restored if dirty
- 🦀 **Rust smart cache**: optionally share a single Cargo `target/` at repo root across all sessions

## 🎬 Demo

```vim
" 1) Start a couple of agents
:AICSession claude --name refactor-auth
:AICSession codex  --name add-tests

" 2) Work with each agent in its tab

" 3) Close the agent tabs when done
"    On close: auto-commit, prompt to land via Neogit, cherry-pick -n
"    Worktree is removed; branch aic/<provider>/<id>-<slug> is preserved
```

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "cyphersnake/agents-in-a-chest.nvim",
  url = "https://codeberg.org/cyphersnake/agents-in-a-chest.nvim",
  dependencies = {
    "NeogitOrg/neogit",      -- Required for interactive landing (:AICEnd)
    "nvim-lua/plenary.nvim", -- Required for tests only
  },
  cmd = { "AICSession", "AICAbort", "AICCleanup", "AICEnd" }, -- Load plugin when these commands are used
  config = function()
    require("agents_in_a_chest").setup({
      -- your configuration
    })
  end,
  keys = {
    { "<leader>lc", "<cmd>AICSession claude --name session<cr>", desc = "Claude session" },
    { "<leader>lx", "<cmd>AICSession codex --name session<cr>", desc = "Codex session" },
    { "<leader>la", "<cmd>AICAbort<cr>", desc = "Abort AIC session" },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "cyphersnake/agents-in-a-chest.nvim",
  requires = {
    { "NeogitOrg/neogit" },
  },
  config = function()
    require("agents_in_a_chest").setup({})
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'NeogitOrg/neogit'
Plug 'https://codeberg.org/cyphersnake/agents-in-a-chest.nvim'
```

## 🚀 Usage

### Main Flow

```vim
" 1) Create a few agents (parallel tabs)
:AICSession claude --name refactor-auth      " base: HEAD by default
:AICSession codex  --name add-tests --base develop

" 2) Collaborate with each agent in its tab
"    Edit, run, iterate — all inside isolated worktrees

" 3) Close the agent tabs when done
"    This triggers auto-commit and the landing prompt (Neogit)

" 4) In Neogit, cherry-pick -n onto your base branch
"    Review, stage if needed, then commit with the prefilled message
```

Notes:
- `:AICEnd` is optional; closing the tab runs the same finalize flow.
- `:AICAbort` force-ends the current session (also safe).
- `:AICCleanup` removes orphan worktrees if anything gets stuck.

## ⚙️ Configuration

```lua
require("agents_in_a_chest").setup({
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

  -- v0.2.0 landing flow
  landing = {
    -- base_branch = "main",  -- optional; if omitted, detected from origin/HEAD → main/master → current
    auto_prompt = true,       -- ask to land when ending a session or when the terminal exits
  },

  -- Rust projects: share Cargo target across worktrees
  rust = {
    share_target_dir = true,   -- export CARGO_TARGET_DIR for Rust repos
    -- target_dir = "/path/to/shared/target", -- default: <repo>/target
    -- env_name = "CARGO_TARGET_DIR",        -- override if needed
    -- detect = true,                         -- detect Cargo.toml/rust-toolchain*
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
worktrees_root = "/tmp/aic-sessions",

-- Or use a custom prefix
worktrees_prefix = "ai-sandbox",
```
</details>

## 📝 Requirements

- **Neovim** ≥ 0.10
- **Git** with worktree support
- **Neogit** for interactive landing via `:AICEnd`
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
  - [ ] List active sessions (`:AICList`)
  - [ ] Switch between sessions (`:AICSwitch`)
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

- **Issues**: [Codeberg Issues](https://codeberg.org/cyphersnake/agents-in-a-chest.nvim/issues)
- **Mirror**: [GitHub Mirror](https://github.com/cyphersnake/agents-in-a-chest.nvim) (read-only)

---

<div align="center">
Made with ❤️ for the Neovim community
</div>
