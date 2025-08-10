# Repository Guidelines

## Project Structure & Module Organization
- Source: `lua/llm_legion/**/*.lua` (core modules) and `plugin/llm-legion.lua` (autoload/entry).
- Docs: `doc/llm-legion.txt` (help file) and examples under `examples/`.
- Tests: `tests/` (Plenary/Busted specs) and `tests/minimal.vim` for headless runs.
- Assets: `media/` (gifs/screens), `doc/img/` for help images.

## Build, Test, and Development Commands
- `stylua .`: Formats Lua code (requires Stylua config).
- `luacheck lua/`: Lints Lua (if configured).
- `make test` or:
  `nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }" -c qa`
  Runs the test suite headlessly.
- Local dev without install: launch `nvim` in repo and `:set rtp+=.` then `:lua require('llm_legion').setup({})`.

## Coding Style & Naming Conventions
- Indentation: 2 spaces; UTF‑8; max line ~100.
- Modules: `llm_legion.*`; files use `snake_case.lua`.
- Public API: `require('llm_legion').setup{}` and `require('llm_legion').<feature>()`.
- Use `vim.notify` for user‑visible messages; guard Neovim APIs with version checks.
- Format with Stylua before commits; keep diffs minimal and focused.

## Testing Guidelines
- Framework: `plenary.nvim` with Busted‑style specs.
- Naming: `tests/<area>/*_spec.lua` with clear arrange/act/assert blocks.
- Mocks: Prefer lightweight fakes; avoid touching user config or network in tests.
- Run tests headless (see command above). Add coverage via `luacov` if present.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`). Scope example: `feat(core): add token cache`.
- PRs: Include summary, rationale, screenshots/asciinema for UX, and linked issues.
- Tests: Required for fixes/features; update docs (`doc/llm-legion.txt`) for user‑facing changes.
- CI: Ensure formatter/linter/tests pass locally before opening a PR.

## Security & Configuration Tips
- Never commit API keys; read tokens via env vars (e.g., `LLM_API_KEY`).
- Provide user options only through `setup{}`; validate inputs and defaults.
- Avoid synchronous/blocking calls on the main loop; prefer async jobs/schedules.
