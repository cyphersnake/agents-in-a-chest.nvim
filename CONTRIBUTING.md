# Contributing to llm-legion.nvim

First off, thank you for considering contributing to llm-legion.nvim! 

## Code of Conduct

Be respectful and constructive in all interactions. We're all here to improve the plugin together.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- Neovim version (`nvim --version`)
- Plugin version/commit
- Minimal reproduction config
- Steps to reproduce
- Expected vs actual behavior
- Error messages/logs

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. Provide:

- Clear use case explanation
- Current vs desired behavior
- Why this would be useful to most users
- Possible implementation approach

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Follow existing code style (2-space indentation, snake_case)
3. Add tests for new functionality
4. Ensure all tests pass: `make test`
5. Update documentation if needed
6. Use conventional commit messages

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/llm-legion.nvim
cd llm-legion.nvim

# Install test dependencies
git clone https://github.com/nvim-lua/plenary.nvim tests/vendor/plenary.nvim

# Run tests
make test

# Test in Neovim
nvim -u tests/minimal.vim
```

## Code Style

- Lua 5.1 compatible
- 2 spaces indentation
- Max line length: ~100 chars
- Functions: `snake_case`
- Constants: `UPPER_CASE`
- Local variables at top of scope
- Comments for complex logic

## Testing

- Write tests for new features
- Place in `tests/*_spec.lua`
- Use Plenary's Busted-style assertions
- Mock external dependencies when possible

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new provider auto-detection
fix: handle worktree creation race condition
docs: update installation instructions
test: add concurrent session tests
refactor: extract git operations module
perf: optimize session cleanup
```

## Questions?

Feel free to open an issue for any questions about contributing!
