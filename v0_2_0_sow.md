# Statement of Work — v0.2.0 Core "End Session → Land on `main`" Flow for `llm-legion.nvim`

## Purpose

Building upon the v0.1.0 MVP, deliver a reliable flow where an LLM session auto-commits on its own branch at exit, then optionally lands those changes on `main` via cherry-pick with:

* Interactive staging using Neogit
* Prefilled commit message from the agent's commit
* Preservation of the original agent commit on the `llm/...` branch
* Safe cleanup of the worktree

## Current State (v0.1.0)

The plugin currently implements:
- ✅ Worktree creation in isolated directory structure
- ✅ Branch naming: `llm/<provider>/<SessionID>-<slug>`
- ✅ Session lifecycle with terminal in new tab
- ✅ Auto-commit on exit (via `on_exit` callback and `VimLeavePre`)
- ✅ Worktree removal with branch preservation
- ✅ `:LLMSession`, `:LLMAbort`, `:LLMCleanup` commands
- ✅ Provider configuration system

## Non-Goals (explicitly out of scope for v0.2.0)

* Session listing/dashboard functionality
* PR tooling, path allowlists, hooks/lint/test gates
* Multi-commit curation paths (we support "one commit" happy path)
* Conflict resolution automation (we detect and bail)
* Support for Git UIs other than Neogit

## User Stories

1. **As a user**, when I end an LLM session, the plugin auto-commits to the session branch and asks whether to land changes on `main`.
2. **If I say yes**, the plugin applies the session commit onto `main` **without committing**, opens Neogit, and preloads the agent's message so I can tweak it and stage hunks/files interactively.
3. **After I commit**, the worktree is removed; the `llm/...` branch (and the agent commit) remain for provenance.
4. **If `main` is dirty**, the plugin auto-stashes, lets me commit, and restores state afterward.

## New Commands & UX

### Enhanced Commands

* **`:LLMEnd`** (NEW)
  1. Auto-commit in the worktree (if uncommitted changes exist)
  2. Prompt: "Cherry-pick this into `main` now?" → Yes/No
  3. If Yes: switch to `main`, `cherry-pick -n` the agent commit, preload commit message, open Neogit for interactive staging/commit, then cleanup
  4. If No: just removes worktree, keeps branch

* **`:LLMAbort`** (ENHANCED)
  - Current: Stops terminal job
  - v0.2.0: Auto-commit (if needed), skip landing prompt, remove worktree, keep branch

* **`:LLMSession`** (UNCHANGED)
  - Existing behavior preserved

### Neogit Integration

* Open with `:Neogit kind=replace` to reuse current window
* Commit message prefilled via `.git/LLM_EDITMSG` and `commit.template`
* User can stage/unstage hunks and files interactively
* After commit, automatic cleanup and state restoration

### Prefilled Commit Message

* Write original agent message to `.git/LLM_EDITMSG`
* Set `git config --local commit.template .git/LLM_EDITMSG` for this commit only
* Restore prior `commit.template` afterward and remove `.git/LLM_EDITMSG`

### Worktree Cleanup & Provenance

* Remove worktree after landing; **do not delete** `llm/...` branch
* Branch remains for audit trail and potential future reference

## Implementation Plan

### New Module Structure

Building on existing `lua/llm_legion/init.lua`:

**New modules to add:**
* `lua/llm_legion/finalize.lua` — implements `:LLMEnd` flow
* `lua/llm_legion/git_helpers.lua` — stash management, cherry-pick wrapper

**Enhancements to existing:**
* `init.lua` — add `:LLMEnd` command, enhance abort logic

### Exact Git Operations (happy path)

**In worktree (on `llm/...`) during `:LLMEnd`:**
```bash
git add -A
git commit -m "wip(llm-legion): <provider>/<name> @ <timestamp> [<id>]"   # if uncommitted
LLM_SHA=$(git rev-parse HEAD)
ORIG_MSG=$(git log -1 --pretty=%B)
```

**In repo root to land on `main`:**
```bash
# If dirty, auto-stash tracked & untracked
git status --porcelain
[dirty] git stash push -u -k -m llm-autosave-<id>

git switch main
git cherry-pick -n $LLM_SHA     # apply, but do not create commit

printf "%s\n" "$ORIG_MSG" > .git/LLM_EDITMSG
OLD_TEMPLATE=$(git config --local commit.template)
git config --local commit.template .git/LLM_EDITMSG
```

**Open Neogit → user stages hunks/files and commits. After commit:**
```bash
git config --local --unset commit.template
[had old template] git config --local commit.template "$OLD_TEMPLATE"
rm -f .git/LLM_EDITMSG
[stashed earlier?] git stash pop || true
```

**Finally:**
```bash
git worktree remove --force <session_worktree_path>   # keep llm/... branch
```

**Error/Conflict:**
If `git cherry-pick -n` conflicts, abort landing, restore pre-state, notify user, keep everything intact.

## Configuration

```lua
require("llm_legion").setup({
  -- Existing v0.1.0 config preserved
  
  -- New v0.2.0 options:
  landing = {
    base_branch = "main",           -- default landing target
    auto_prompt = true,             -- prompt to land on :LLMEnd
  },
})
```

## Acceptance Criteria

1. **Auto-commit on end**
   * If the session has uncommitted changes, `:LLMEnd` creates a commit with standard template
   
2. **Prompt to land**
   * A single confirm dialog; "Yes" proceeds; "No" just removes the worktree and leaves the branch
   
3. **Interactive cherry-pick with Neogit**
   * After "Yes", `main` is checked out, changes are applied **without commit**, and Neogit opens
   * The commit editor opens with the **agent's message prefilled**
   * User can stage/unstage hunks/files and edit the message; committing succeeds
   
4. **Cleanup**
   * Worktree is removed; `llm/...` branch remains with the agent commit
   * Any temporary `commit.template` and edit file are cleaned up
   * If a stash was created, it is popped (or left clearly indicated if pop fails)
   
5. **No data loss**
   * If landing fails (e.g., conflict), state is reverted or clearly left for manual resolution, with the agent branch intact

## Test Plan

**Test Cases:**
1. Clean `main`, Neogit present → full happy path
2. Dirty `main` (tracked+untracked) → stash/push; commit; stash/pop
3. Repo has pre-existing `commit.template` → value is restored afterward
4. Conflict on `cherry-pick -n` → abort landing, show message, nothing lost
5. Multiple prior commits on session branch → latest one is used
6. No Neogit installed → graceful error message

## Development Roadmap

**Phase 1 — Core finalize flow**
* Implement `:LLMEnd` command registration
* Add finalize module with:
  * Worktree auto-commit logic (reuse existing)
  * Landing prompt dialog
  * `cherry-pick -n` onto `main`
  * Commit template prefill mechanism
  
**Phase 2 — Neogit integration**
* Neogit detection and opening
* Stash management for dirty repos
* Config restore after commit
* Enhanced `:LLMAbort` with auto-commit

**Phase 3 — Hardening & polish**
* Conflict detection and graceful bailout
* Comprehensive test suite
* Documentation updates
* Edge case handling (CWD management during operations)

## Implementation Notes

**Key Functions to Add:**

```lua
-- lua/llm_legion/finalize.lua
M.end_session(session) -- Main landing flow
M.prompt_landing() -- Yes/No dialog
M.apply_changes(sha, target_branch) -- cherry-pick -n
M.setup_commit_template(message) -- Template management
M.restore_commit_template(old_value) -- Cleanup
M.open_neogit() -- Launch Neogit

-- lua/llm_legion/git_helpers.lua
M.is_dirty() -- Check working tree status
M.stash_push(id) -- Create named stash
M.stash_pop_safe(id) -- Restore if compatible
M.get_commit_message(sha) -- Extract message
```

**Integration Points:**
* Hook into existing `on_exit` callback to offer landing
* Reuse existing `exec_git()` and state management
* Preserve backward compatibility with v0.1.0 behavior

## Deliverables

* Enhanced plugin implementing `:LLMEnd` flow with Neogit integration
* Updated README with v0.2.0 features and workflow
* Extended test suite covering landing scenarios
* CHANGELOG entry documenting new features

## Success Metrics

* Zero data loss during landing operations
* Landing flow completes in < 5 seconds for typical repos
* Neogit integration works reliably
* Existing v0.1.0 functionality remains unchanged