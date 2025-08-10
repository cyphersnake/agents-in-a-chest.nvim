# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-08-10

### Added
- `:LLMEnd` to end a session and optionally land changes onto the base branch via Neogit (`git cherry-pick -n`).
- Auto-finalize: closing the session tab/terminal triggers the same landing prompt automatically.
- Prefilled commit message for landing via temporary `.git/LLM_EDITMSG` and `commit.template` override.
- Safe stash/pop of dirty base branch before/after landing.
- Base branch detection from `origin/HEAD`, falling back to `main`, `master`, or current branch.
- Config option `landing = { base_branch, auto_prompt }`.

### Fixed
- Avoid calling blocking APIs in fast event contexts (timer) when watching for commit completion.
- Ensure Neogit opens in the base repo’s cwd so staged changes appear correctly.

### Docs
- README and help updated for auto-finalize and Neogit landing flow.

## [0.1.1] - 2025-08-10

### Fixed
- Cleanup no longer leaves worktree directories behind in rare cases:
  - Avoid removing a worktree while CWD is inside it
  - Run `git worktree remove` from the repository root
  - Store `repo_root` per session for reliable cleanup
  - Improve VimLeave cleanup path accordingly

### Tests
- Add cleanup stability spec to assert no leaf worktree directories remain after session exit

## [0.1.0] - 2025-01-10

### Added
- Initial MVP release
- Core worktree management with JIT (Just-In-Time) lifecycle
- Support for multiple LLM providers (Claude, Codex)
- Auto-commit on session exit
- Tab-based session management
- Concurrent session support
- `:LLMSession` command with `--name` and `--base` options
- `:LLMAbort` command for graceful session termination
- `:LLMCleanup` command for orphaned worktree cleanup
- Automatic VimLeavePre cleanup handler
- Path safety guard to prevent worktrees inside repository
- Git lock retry with jitter backoff
- Basic test suite with Plenary
- Makefile for streamlined testing

### Security
- Worktrees are always created outside the repository
- Provider CLIs require external authentication

[Unreleased]: https://codeberg.org/cyphersnake/llm-legion.nvim/compare/v0.2.0...HEAD
[0.2.0]: https://codeberg.org/cyphersnake/llm-legion.nvim/releases/tag/v0.2.0
[0.1.1]: https://codeberg.org/cyphersnake/llm-legion.nvim/releases/tag/v0.1.1
[0.1.0]: https://codeberg.org/cyphersnake/llm-legion.nvim/releases/tag/v0.1.0
