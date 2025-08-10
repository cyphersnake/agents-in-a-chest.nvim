# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://codeberg.org/cyphersnake/llm-legion.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://codeberg.org/cyphersnake/llm-legion.nvim/releases/tag/v0.1.0
