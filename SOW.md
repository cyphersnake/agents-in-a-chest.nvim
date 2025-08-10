# Statement of Work — `llm-worktree.nvim` MVP

## Objective

Implement a Neovim plugin that launches an LLM coding agent (`claude` or `codex`) in a new **tab**, isolated in a just‑in‑time **Git worktree** located **outside** the main working tree (in the repo’s parent). When the terminal session ends, the plugin **auto‑commits any changes** on the worktree branch and **removes the worktree directory** (branch is preserved). Multiple concurrent sessions are supported (one per tab).

## Scope (functional)

### 1) Command

```
:LLMSession {provider} --name <slug> [--base <ref>]
```

* `provider`: one of the configured providers (e.g., `claude`, `codex`). Unknown provider → error.
* `--name <slug>`: **required**; human‑readable slug used for tab title and appended to branch and folder names. Slug is sanitized to `[a-z0-9._-]+`; invalid characters replaced with `-`.
* `--base <ref>`: Git ref to base for the worktree; default `HEAD`.

### 2) Lifecycle (JIT: add → run → commit → remove)

1. **Resolve repo root** via `git rev-parse --show-toplevel`; error if not a Git repo.
2. **Compute paths**:

   * `repo_parent = realpath(repo_root)/..`
   * `worktrees_root = repo_parent/.llm-worktrees`
   * `repo_key = <basename(repo_root)>-<short_hash(realpath(repo_root))>`
   * `SessionID = YYYYMMDD-HHMMSS-<5hex>`
   * `session_suffix = <SessionID>-<slug>`
   * `worktree_path = <worktrees_root>/<repo_key>/<session_suffix>`
   * `branch = llm/<provider>/<session_suffix>`
   * **Guard**: if `worktree_path` resides inside `repo_root` after `realpath`, hard‑fail (should not happen).
3. **Create worktree**:

   * `git worktree add -b <branch> <worktree_path> <base>`
   * If transient Git lock error, retry once after short backoff.
4. **Open UI**:

   * Open a **new tab**, set `tcd` to `worktree_path`.
   * Open a **terminal** via `termopen()` with `cwd = worktree_path`, executing the provider command and args from config.
   * Set tab title and terminal buffer name to `llm:<provider>:<slug>`.
5. **On terminal exit** (or Neovim exit) — **JIT Worktree Remove (JIT‑WTR) policy**:

   * **Auto‑commit** (if there are changes):

     * `git add -A`
     * `git commit -m "wip(llm-worktree): <provider>/<slug> @ <ISO8601> [<SessionID>]"`
       If there’s nothing to commit, skip without error.
   * **Cleanup**:

     * Close the session terminal buffer. If the tab only contains this buffer, close the tab; otherwise leave the tab layout intact.
     * `git worktree remove --force <worktree_path>`
     * **Do not delete the branch.**

### 3) Concurrency

* Each invocation creates an independent tab/session. No global lock; N sessions may run in parallel.
* If Git returns a lock‑related failure on add/remove, retry once with jittered backoff.

### 4) State & IDs

* `SessionID = YYYYMMDD-HHMMSS-<5hex>`; uniqueness per process; 5‑hex from high‑res time‑seeded RNG.
* In‑memory registry entry per session:
  `{ id, name, provider, tabnr, term_job_id, worktree_path, branch }` used for cleanup.

### 5) Commands (auxiliary)

* `:LLMAbort` — forcibly close the running terminal in the **current tab** and trigger the same JIT‑WTR cleanup (auto‑commit then remove).
* `:LLMCleanup` — prune stray session directories under `<worktrees_root>/*`:

  * If `git worktree list` contains `<path>` → `git worktree remove --force <path>`;
  * Else if the directory exists only on disk → delete it;
  * Then run `git worktree prune --verbose`.
    All cleanup actions are idempotent.

## Non‑functional / Constraints

* **Neovim**: ≥ **0.10**. Implementation in **Lua**; use `vim.fn.termopen` for the agent and `vim.system` for Git calls.
* **OS**: Linux/macOS.
* **Dependencies**: `git` with worktree support; provider CLIs installed and authenticated externally.
* **Security**: No sandboxing. The agent process starts with `cwd = worktree_path`; standard local user permissions apply.
* **Failure handling**: Clear `vim.notify` messages for: missing Git/provider CLI, non‑repo, invalid base ref, path guard fails, Git errors. Cleanup is tolerant and idempotent.
* **Telemetry**: none.

## Configuration (minimal)

```lua
require("llm_worktree").setup({
  worktrees_root = nil, -- default: realpath(repo_root)/"../.llm-worktrees"
  default_base   = "HEAD",
  providers = {
    claude = { cmd = "claude", args = {} },
    codex  = { cmd = "codex",  args = {} },
  },
})
-- example keymaps
-- vim.keymap.set("n", "<leader>lc", ':LLMSession claude --name session<CR>')
-- vim.keymap.set("n", "<leader>lx", ':LLMSession codex  --name fix-bug-123<CR>')
```

## Deliverables

* Plugin repo with:

  * `lua/llm_worktree/init.lua` (core),
  * `README.md` (install, usage, constraints, path layout, JIT‑WTR policy),
  * Minimal tests (Plenary/Busted) covering:

    * SessionID/slug sanitation & naming;
    * Lifecycle FSM including auto‑commit and remove;
    * Cleanup idempotency and `git worktree` metadata handling;
    * Guard that `worktree_path` is outside the repo.
  * Example config snippet as above.

## Acceptance Criteria

* From any Git repo, `:LLMSession <provider> --name <slug>`:

  * Creates a new worktree at `<repo_parent>/.llm-worktrees/<repo_key>/<SessionID>-<slug>`,
  * On a new branch `llm/<provider>/<SessionID>-<slug>` based on `<base>`,
  * Opens a new tab/terminal running the provider with `cwd = worktree_path`.
* On terminal exit (or `:LLMAbort`):

  * If there are changes, a commit with message `wip(llm-worktree): <provider>/<slug> @ <ISO8601> [<SessionID>]` is created on the session branch.
  * The terminal buffer is closed; the tab is closed **only** if it contains no other windows.
  * The worktree directory is removed (`git worktree remove --force <path>`), and the branch **remains**.
* Multiple sessions can be started/closed independently without interfering with each other.
* `:LLMCleanup` safely removes abandoned session directories and prunes stale Git metadata.
* Errors surface via `vim.notify` with a consistent `[llm-worktree]` prefix.
