# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin called `llm-legion` (formerly planned as `llm-worktree.nvim`) that launches LLM coding agents in isolated Git worktrees. The plugin creates temporary worktrees outside the main working tree, runs the agent in a terminal tab, and automatically commits changes when the session ends.

## Build and Development Commands

- **Format code**: `stylua .` (requires Stylua configuration)
- **Lint code**: `luacheck lua/` (if configured)
- **Run tests**: `make test` or:
  ```
  nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }" -c qa
  ```
- **Local development**: Launch nvim in repo, then `:set rtp+=.` and `:lua require('llm_legion').setup({})`

## Architecture and Core Concepts

### Module Structure
- **Entry point**: `plugin/llm-legion.lua` (autoload/entry)
- **Core modules**: `lua/llm_legion/**/*.lua`
- **Main module**: `lua/llm_legion/init.lua` (implements setup and core lifecycle)
- **Public API**: `require('llm_legion').setup({})` and feature methods

### Key Implementation Details

1. **Worktree Management**:
   - Creates worktrees at `<repo_parent>/.<repo>-worktrees/<repo_key>/<session_suffix>`
   - Branch naming: `llm/<provider>/<SessionID>-<slug>`
   - Uses JIT (Just-In-Time) policy: add → run → commit → remove

2. **Session Lifecycle**:
   - Resolve repo root via `git rev-parse --show-toplevel`
   - Create worktree with `git worktree add -b <branch> <path> <base>`
   - Open terminal in new tab with `vim.fn.termopen()`
   - On exit: auto-commit changes, remove worktree (keep branch)

3. **State Management**:
   - SessionID format: `YYYYMMDD-HHMMSS-<5hex>`
   - In-memory registry tracks: `{ id, name, provider, tabnr, term_job_id, worktree_path, branch }`

### Commands to Implement

- `:LLMSession {provider} --name <slug> [--base <ref>]` - Main command to start session
- `:LLMAbort` - Force close current tab's terminal and cleanup
- `:LLMCleanup` - Prune stray session directories

## Testing Guidelines

- Framework: Plenary.nvim with Busted-style specs
- Test files: `tests/<area>/*_spec.lua`
- Coverage areas:
  - SessionID/slug sanitization
  - Lifecycle FSM (auto-commit and remove)
  - Cleanup idempotency
  - Path validation (worktree outside repo)

## Code Style

- **Indentation**: 2 spaces, UTF-8, max line ~100 chars
- **File naming**: `snake_case.lua`
- **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
- **Error handling**: Use `vim.notify` with `[llm-legion]` prefix
- **Async operations**: Use `vim.system` for Git calls, avoid blocking main loop

## Security Considerations

- Never commit API keys - read from environment variables
- Validate all user inputs, especially slug sanitization to `[a-z0-9._-]+`
- Guard against worktree paths inside the main repo
- Provider CLIs must be authenticated externally

## Constraints

- **Neovim version**: ≥ 0.10
- **OS support**: Linux/macOS
- **Dependencies**: Git with worktree support, provider CLIs (claude, codex, etc.)
