local G = require('llm_legion.git_helpers')

local M = {}

local PREFIX = "[llm-legion] "
local function notify(msg, level)
  vim.notify(PREFIX .. msg, level or vim.log.levels.INFO)
end

local function file_write(path, contents)
  local ok, fd = pcall(vim.loop.fs_open, path, "w", 420) -- 0644
  if not ok or not fd then return false end
  vim.loop.fs_write(fd, contents)
  vim.loop.fs_close(fd)
  return true
end

local function file_remove(path)
  pcall(vim.loop.fs_unlink, path)
end

local function neogit_available()
  if vim.fn.exists(":Neogit") == 2 then return true end
  local ok = pcall(require, 'neogit')
  return ok
end

local function open_neogit()
  if not neogit_available() then
    return false, "Neogit is not installed"
  end
  pcall(vim.cmd, "Neogit kind=replace")
  return true
end

local function git_commit_if_needed(sess)
  G.exec_git({ "add", "-A" }, sess.worktree_path)
  local msg = string.format(
    "wip(llm-legion): %s/%s @ %s [%s]",
    sess.provider, sess.name, os.date("!%Y-%m-%dT%H:%M:%SZ"), sess.id
  )
  local c, _o, e = G.exec_git({ "commit", "-m", msg }, sess.worktree_path)
  if c ~= 0 then
    local em = tostring(e or "")
    if not (em:match("nothing to commit") or em:match("no changes added") or em:match("nothing added")) then
      notify("git commit failed for session '" .. sess.name .. "'", vim.log.levels.WARN)
    end
  end
end

local function path_dirname(p)
  return vim.fn.fnamemodify(p, ":h")
end

local function dir_exists(p)
  local st = vim.loop.fs_stat(p)
  return st and st.type == 'directory'
end

local function dir_is_empty(p)
  local fs = vim.loop.fs_scandir(p)
  if not fs then return true end
  local name = vim.loop.fs_scandir_next(fs)
  return name == nil
end

local function rm_rf(p)
  pcall(vim.fn.delete, p, 'rf')
end

local function prune_empty_dirs(start_dir, stop_after)
  local current = start_dir
  for i = 1, (stop_after or 2) do
    if not dir_exists(current) then break end
    if not dir_is_empty(current) then break end
    rm_rf(current)
    current = path_dirname(current)
  end
end

local function remove_worktree(sess)
  local root = sess.repo_root or (sess.worktree_path .. "/..")
  -- Ensure we are not inside the worktree when removing
  local cwd = vim.fn.getcwd()
  local function is_inside(child, parent)
    child = vim.fn.fnamemodify(child, ':p')
    parent = vim.fn.fnamemodify(parent, ':p')
    if child == parent then return true end
    if not child:find('^' .. vim.pesc(parent)) then return false end
    local ch = child:sub(#parent + 1, #parent + 1)
    return ch == '/' or ch == '\\'
  end
  if is_inside(cwd, sess.worktree_path) then
    pcall(vim.cmd, 'tcd ' .. vim.fn.fnameescape(root))
  end
  -- If repo root is gone, skip git and just remove directories.
  if dir_exists(root) then
    local rc, _o2, _e2 = G.exec_git({ "worktree", "remove", "--force", sess.worktree_path }, root)
    if rc ~= 0 then
      notify("git worktree remove failed for '" .. sess.worktree_path .. "'", vim.log.levels.WARN)
    end
  end
  -- If the directory still exists, delete it and prune empty parents (two levels)
  if dir_exists(sess.worktree_path) then
    rm_rf(sess.worktree_path)
  end
  local parent1 = path_dirname(sess.worktree_path)
  prune_empty_dirs(parent1, 2) -- remove parent1 if empty, then its parent if empty
end

local function prompt_yes_no(target_branch)
  if vim.ui and vim.ui.select then
    local co = coroutine.running()
    if co then
      local selected
      local prompt = string.format("Cherry-pick this into %s now?", target_branch or "base")
      vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(item)
        selected = item
        coroutine.resume(co)
      end)
      coroutine.yield()
      return selected == "Yes"
    end
  end
  local ans = vim.fn.confirm(string.format("Cherry-pick this into %s now?", target_branch or "base"), "&Yes\n&No", 1)
  return ans == 1
end

-- Commit message prefill helper using Neogit/commit buffer hooks
local CT = require('llm_legion.commit_template')

local function start_commit_watcher(repo_root, prev_head, on_commit)
  local timer = vim.loop.new_timer()
  local stopped = false
  timer:start(500, 500, function()
    if stopped then return end
    -- Run git check on main loop to avoid fast-event blocking
    vim.schedule(function()
      if stopped then return end
      -- If repo root disappears (e.g., ephemeral worktree or deleted repo), stop quietly.
      if not dir_exists(repo_root) then
        stopped = true
        timer:stop(); timer:close()
        notify("landing watcher stopped: repo directory missing", vim.log.levels.WARN)
        return
      end
      local head = (G.rev_parse("HEAD", repo_root))
      if head and head ~= prev_head then
        stopped = true
        timer:stop(); timer:close()
        vim.schedule(on_commit)
      end
    end)
  end)
  return function()
    if not stopped then stopped = true; timer:stop(); timer:close() end
  end
end

local function resolve_base_branch(core, sess)
  local cfg = core.config or {}
  local repo = sess.repo_root
  local function branch_valid(b)
    if not b or b == '' then return false end
    if G.branch_exists(b, repo) then return true end
    if G.remote_branch_exists('origin', b, repo) then return true end
    return false
  end
  -- 1) Prefer a real branch associated with the session base
  if sess.base_ref and sess.base_ref ~= '' then
    local c, o, _ = G.exec_git({ 'rev-parse', '--abbrev-ref', sess.base_ref }, repo)
    if c == 0 then
      local name = vim.trim(o or '')
      if name ~= '' and name ~= 'HEAD' and branch_valid(name) then return name end
    end
  end
  -- 2) Use configured base if valid; otherwise ignore and fall back
  if cfg.landing and cfg.landing.base_branch and branch_valid(cfg.landing.base_branch) then
    return cfg.landing.base_branch
  end
  -- 3) Detect repo default (origin/HEAD → main/master → current)
  return G.get_default_branch(repo)
end

function M.end_session(sess)
  local core = require('llm_legion')
  core._ensure_setup()
  local tab = vim.api.nvim_get_current_tabpage()
  local cur_sess = sess or core._state.sessions_by_tab[tab]
  if not cur_sess then
    notify("no active session in this tab", vim.log.levels.WARN)
    return
  end
  if cur_sess.finalizing then return end
  cur_sess.finalizing = true

  local function close_session_tab()
    -- Close the session's tab specifically, without touching others
    if cur_sess and cur_sess.tab then
      local ok_switch = pcall(vim.api.nvim_set_current_tabpage, cur_sess.tab)
      if ok_switch then
        pcall(vim.cmd, 'tabclose')
      end
    end
  end

  -- Ensure any pending changes in worktree are committed
  git_commit_if_needed(cur_sess)
  local sha, _e = G.rev_parse("HEAD", cur_sess.worktree_path)
  if not sha then
    notify("failed to resolve session commit SHA; cleaning up", vim.log.levels.ERROR)
    -- Best-effort cleanup so we don't leave timers or tabs lingering
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    return
  end
  local msg, _e2 = G.get_commit_message(sha, cur_sess.worktree_path)
  if not msg or msg == "" then msg = string.format("llm: %s/%s [%s]", cur_sess.provider, cur_sess.name, cur_sess.id) end

  -- If there are no new commits since session base, skip landing
  local repo = cur_sess.repo_root
  if cur_sess.base_sha and cur_sess.base_sha ~= "" then
    if cur_sess.base_sha == sha then
      -- Nothing to land; just cleanup
      remove_worktree(cur_sess)
      core._state.sessions_by_tab[cur_sess.tab] = nil
      close_session_tab()
      notify("no changes to land; worktree cleaned up")
      return
    end
  end

  local cfg = core.config or { landing = { auto_prompt = true } }
  -- If session was explicitly aborted, skip landing and just cleanup
  if cur_sess.abort then
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    notify("session aborted; worktree cleaned up")
    return
  end
  local land = true
  if cfg.landing and cfg.landing.auto_prompt ~= false then
    local base_preview = resolve_base_branch(core, cur_sess)
    land = prompt_yes_no(base_preview)
  end

  if not land then
    -- Just remove worktree; keep branch for provenance
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    return
  end

  if not neogit_available() then
    notify("Neogit not available; cannot land interactively", vim.log.levels.ERROR)
    -- Clean up worktree; keep branch
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    return
  end

  -- Prepare landing on base branch
  local base = resolve_base_branch(core, cur_sess)

  local dirty = G.is_dirty(repo)
  local stashed = false
  if dirty then
    local ok = G.stash_push(cur_sess.id, repo)
    stashed = ok
  end

  local ok_switch, e1 = G.ensure_switch_branch(base, repo)
  if not ok_switch then
    notify("failed to switch to base branch '" .. base .. "': " .. tostring(e1 or ""), vim.log.levels.ERROR)
    if stashed then G.stash_pop_safe(repo) end
    return
  end

  local c2, _o2, e2 = G.exec_git({ "cherry-pick", "-n", sha }, repo)
  if c2 ~= 0 then
    notify("cherry-pick failed; aborting landing", vim.log.levels.ERROR)
    G.exec_git({ "cherry-pick", "--abort" }, repo)
    if stashed then G.stash_pop_safe(repo) end
    -- remove worktree and close tab; keep branch intact
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    return
  end

  -- Ensure Neovim tab-local cwd points at the base repo for Neogit
  pcall(vim.cmd, 'tcd ' .. vim.fn.fnameescape(repo))

  local pre_head = G.rev_parse("HEAD", repo)

  -- Open Neogit and watch for commit to complete cleanup
  local ok, err = open_neogit()
  if not ok then
    notify(err or "failed to open Neogit", vim.log.levels.ERROR)
    -- leave working tree dirty with applied changes
    if stashed then G.stash_pop_safe(repo) end
    return
  end

  -- Prefill the next commit message in the commit editor buffer (no git config changes)
  CT.schedule(repo, msg)

  local stop_watch = start_commit_watcher(repo, pre_head, function()
    if stashed then G.stash_pop_safe(repo) end
    -- remove worktree and close tab
    remove_worktree(cur_sess)
    core._state.sessions_by_tab[cur_sess.tab] = nil
    close_session_tab()
    notify("landing complete; worktree cleaned up")
  end)

  -- If the user quits before committing, ensure we stop the watcher when Neogit buffer closes
  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    once = true,
    callback = function()
      stop_watch()
    end,
  })
end

return M
