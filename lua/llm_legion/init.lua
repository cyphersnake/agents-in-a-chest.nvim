local M = {}

-- Prefix for all user-facing messages
local PREFIX = "[llm-legion] "

-- Default configuration
local DEFAULTS = {
  worktrees_root = nil, -- computed from repo root if nil
  worktrees_prefix = nil, -- if nil, defaults to repo basename; used when worktrees_root is nil
  default_base = "HEAD",
  providers = {
    claude = { cmd = "claude", args = {} },
    codex = { cmd = "codex", args = {} },
  },
}

-- Internal state registry
M._state = {
  sessions_by_tab = {}, -- [tab] = { id, name, provider, tab, term_job_id, bufnr, worktree_path, branch }
  configured = false,
  vimleave_autocmd = nil,
}

local function notify(msg, level)
  vim.notify(PREFIX .. msg, level or vim.log.levels.INFO)
end

local function nvim_ok()
  if vim.fn.has("nvim-0.10") == 1 then
    return true
  end
  notify("requires Neovim >= 0.10", vim.log.levels.ERROR)
  return false
end

local function deepcopy(tbl)
  if type(tbl) ~= "table" then return tbl end
  local res = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      res[k] = deepcopy(v)
    else
      res[k] = v
    end
  end
  return res
end

local function merge_tables(dst, src)
  for k, v in pairs(src or {}) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge_tables(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

function M.setup(user)
  if not nvim_ok() then return end
  local cfg = deepcopy(DEFAULTS)
  if type(user) == "table" then
    merge_tables(cfg, user)
  end
  M.config = cfg
  M._state.configured = true
end

function M._ensure_setup()
  if not M._state.configured then
    M.setup({})
  end
end

-- Extract provider names for simple completion
local function provider_names()
  M._ensure_setup()
  local names = {}
  for name, _ in pairs(M.config.providers or {}) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Utility: sanitize slug to [a-z0-9._-]+
local function sanitize_slug(slug)
  slug = tostring(slug or "")
  slug = slug:lower()
  slug = slug:gsub("[^a-z0-9._-]", "-")
  slug = slug:gsub("%-%-+", "-")
  slug = slug:gsub("^%-+", "")
  slug = slug:gsub("%-+$", "")
  return slug
end

-- Utility: session id YYYYMMDD-HHMMSS-<5hex>
local function session_id()
  local ts = os.date("%Y%m%d-%H%M%S")
  local seed = (vim.uv or vim.loop).hrtime()
  math.randomseed(seed % 2^31)
  local n = math.random(0, 0xFFFFF)
  return string.format("%s-%05x", ts, n)
end

local function iso8601_utc()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Utility: run system command with cwd and capture
local function run(cmd, opts, cb)
  opts = opts or {}
  local system = vim.system or vim.fn.system
  if vim.system then
    return vim.system(cmd, { cwd = opts.cwd }, function(obj)
      if cb then cb(obj.code, obj.stdout, obj.stderr) end
    end)
  else
    local out = vim.fn.system(cmd)
    local code = vim.v.shell_error
    if cb then cb(code, out, "") end
  end
end

local function run_blocking(cmd, opts)
  if vim.system then
    local proc = vim.system(cmd, { cwd = (opts or {}).cwd })
    local res = proc:wait()
    return res.code or 1, res.stdout or "", res.stderr or ""
  else
    local out = vim.fn.system(cmd)
    local code = vim.v.shell_error
    return code, out or "", ""
  end
end

local function exec_git(args, cwd)
  local cmd = { "git" }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  return run_blocking(cmd, { cwd = cwd })
end

local function jitter_sleep(ms)
  local wait = ms + math.random(0, 200)
  if vim.wait then
    vim.wait(wait)
  else
    vim.cmd("sleep " .. math.floor(wait) .. "m")
  end
end

local function short_hash(s)
  local ok, digest = pcall(vim.fn.sha256, s)
  if not ok then
    -- fallback: naive sum
    local sum = 0
    for i = 1, #s do sum = (sum + s:byte(i)) % 0xFFFFFFFF end
    digest = string.format("%08x", sum)
  end
  return string.sub(digest, 1, 7)
end

local function basename(path)
  return vim.fs.basename(path)
end

local function abspath(path)
  return vim.fn.fnamemodify(path, ":p")
end

local function ensure_dir(path)
  return vim.fn.mkdir(path, "p") == 1 or vim.loop.fs_stat(path) ~= nil
end

local function is_path_inside(child, parent)
  child = abspath(child)
  parent = abspath(parent)
  if child == parent then return true end
  if not child:find("^" .. vim.pesc(parent)) then return false end
  local ch = child:sub(#parent + 1, #parent + 1)
  return ch == "/" or ch == "\\"
end

-- Resolve repo root or return nil,err
local function repo_root()
  local code, out, err = exec_git({ "rev-parse", "--show-toplevel" })
  if code ~= 0 then
    return nil, (err ~= "" and err or out)
  end
  return vim.trim(out), nil
end

-- Compute all naming and paths for session
local function compute_paths(repo_root_path, provider, slug, id, cfg)
  local real_root = vim.loop.fs_realpath(repo_root_path) or repo_root_path
  local parent = abspath(real_root .. "/..")
  local prefix = (cfg.worktrees_prefix or basename(real_root)):lower()
  local worktrees_root = cfg.worktrees_root or (parent .. "/." .. prefix .. "-worktrees")
  local key = string.format("%s-%s", basename(real_root), short_hash(real_root))
  local suffix = string.format("%s-%s", id, slug)
  local worktree_path = string.format("%s/%s/%s", worktrees_root, key, suffix)
  local branch = string.format("llm/%s/%s", provider, suffix)
  return {
    worktrees_root = worktrees_root,
    repo_key = key,
    session_suffix = suffix,
    worktree_path = worktree_path,
    branch = branch,
  }
end

local function ensure_vimleave_autocmd()
  if M._state.vimleave_autocmd then return end
  M._state.vimleave_autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      -- Best-effort: iterate and cleanup
      for tab, sess in pairs(M._state.sessions_by_tab) do
        pcall(function()
          if sess and sess.worktree_path then
            local wcwd = sess.worktree_path
            -- stage/commit from within the worktree
            exec_git({ "add", "-A" }, wcwd)
            exec_git({ "commit", "-m", string.format(
              "wip(llm-legion): %s/%s @ %s [%s]",
              sess.provider, sess.name, iso8601_utc(), sess.id
            ) }, wcwd)
            -- Leave worktree as process CWD before removal to avoid rmdir issues
            pcall(vim.cmd, "cd " .. vim.fn.fnameescape(sess.repo_root or wcwd .. "/.."))
            -- remove from repo root for reliability
            exec_git({ "worktree", "remove", "--force", wcwd }, sess.repo_root)
          end
        end)
        M._state.sessions_by_tab[tab] = nil
      end
    end,
  })
end

-- Internal: open terminal in new tab and wire on_exit cleanup
local function git_commit_if_needed(sess)
  exec_git({ "add", "-A" }, sess.worktree_path)
  local msg = string.format(
    "wip(llm-legion): %s/%s @ %s [%s]",
    sess.provider, sess.name, iso8601_utc(), sess.id
  )
  local c, _o, e = exec_git({ "commit", "-m", msg }, sess.worktree_path)
  if c ~= 0 then
    local em = tostring(e or "")
    if not (em:match("nothing to commit") or em:match("no changes added") or em:match("nothing added")) then
      notify("git commit failed for session '" .. sess.name .. "'", vim.log.levels.WARN)
    end
  end
end

local function git_remove_worktree(sess)
  -- Run removal from the repo root to avoid failures when CWD is the worktree
  local root = sess.repo_root or abspath(sess.worktree_path .. "/..")
  local rc, _o2, _e2 = exec_git({ "worktree", "remove", "--force", sess.worktree_path }, root)
  if rc ~= 0 then
    notify("git worktree remove failed for '" .. sess.worktree_path .. "'", vim.log.levels.WARN)
  end
end

local function open_session_tab(cfg, sess)
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()
  local path_esc = vim.fn.fnameescape(sess.worktree_path)
  vim.cmd("tcd " .. path_esc)
  local provider_conf = cfg.providers[sess.provider]
  local cmd = { provider_conf.cmd }
  for _, a in ipairs(provider_conf.args or {}) do table.insert(cmd, a) end

  local bufnr = vim.api.nvim_get_current_buf()
  -- run terminal
  local job = vim.fn.termopen(cmd, { cwd = sess.worktree_path, on_exit = function()
    -- on exit: auto-commit changes then remove worktree
    local function cleanup()
      -- If process CWD is inside the worktree, leave it to allow deletion
      local cur_cwd = vim.fn.getcwd()
      if is_path_inside(cur_cwd, sess.worktree_path) then
        pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(sess.repo_root))
      end
      git_commit_if_needed(sess)
      git_remove_worktree(sess)
      -- Close buffers/windows
      local wins = vim.api.nvim_tabpage_list_wins(tab)
      if #wins == 1 then
        local wbuf = vim.api.nvim_win_get_buf(wins[1])
        if wbuf == bufnr then
          pcall(vim.cmd, 'tabclose')
        else
          pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
        end
      else
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      M._state.sessions_by_tab[tab] = nil
    end
    vim.schedule(cleanup)
  end })

  if job <= 0 then
    -- Terminal failed to start; rollback worktree immediately
    notify("failed to start provider terminal; rolling back worktree", vim.log.levels.ERROR)
    git_commit_if_needed(sess)
    git_remove_worktree(sess)
    -- Close the tab we opened
    pcall(vim.cmd, 'tabclose')
    return
  end

  -- set names/titles
  pcall(vim.api.nvim_buf_set_name, bufnr, string.format("llm:%s:%s", sess.provider, sess.name))
  pcall(function()
    local tabnr = vim.api.nvim_tabpage_get_number(tab)
    vim.t[tabnr] = vim.t[tabnr] or {}
    vim.t[tabnr].title = string.format("llm:%s:%s", sess.provider, sess.name)
  end)

  M._state.sessions_by_tab[tab] = {
    id = sess.id,
    name = sess.name,
    provider = sess.provider,
    tab = tab,
    term_job_id = job,
    bufnr = bufnr,
    worktree_path = sess.worktree_path,
    branch = sess.branch,
    repo_root = sess.repo_root,
  }
end

-- Placeholder: session command entrypoint; real implementation in later milestones
function M.session_cmd(args)
  M._ensure_setup()
  if not nvim_ok() then return end
  if not args or #args == 0 then
    notify("usage: :LLMSession {provider} --name <slug> [--base <ref>]", vim.log.levels.WARN)
    return
  end
  ensure_vimleave_autocmd()

  -- Parse
  local provider = args[1]
  local slug, base
  local i = 2
  while i <= #args do
    local tok = args[i]
    if tok == "--name" and args[i + 1] then
      slug = args[i + 1]
      i = i + 2
    elseif tok:match("^%-%-name=") then
      slug = tok:sub(8)
      i = i + 1
    elseif tok == "--base" and args[i + 1] then
      base = args[i + 1]
      i = i + 2
    elseif tok:match("^%-%-base=") then
      base = tok:sub(8)
      i = i + 1
    else
      i = i + 1
    end
  end

  if not (M.config.providers and M.config.providers[provider]) then
    notify("unknown provider '" .. tostring(provider) .. "'", vim.log.levels.ERROR)
    return
  end
  if not slug or slug == "" then
    notify("--name <slug> is required", vim.log.levels.ERROR)
    return
  end
  slug = sanitize_slug(slug)
  if slug == "" then
    notify("slug becomes empty after sanitization", vim.log.levels.ERROR)
    return
  end
  base = base or M.config.default_base or "HEAD"

  -- Provider binary exists?
  local cmd = M.config.providers[provider].cmd
  if vim.fn.executable(cmd) ~= 1 then
    notify("provider CLI not found: " .. tostring(cmd), vim.log.levels.ERROR)
    return
  end

  -- Git repo root
  local root, err = repo_root()
  if not root then
    notify("not a git repository: " .. (err or ""), vim.log.levels.ERROR)
    return
  end

  -- Compute paths
  local id = session_id()
  local p = compute_paths(root, provider, slug, id, M.config)
  -- Guard: ensure worktree path not inside repo
  if is_path_inside(p.worktree_path, root) then
    notify("guard failed: worktree path resolves inside repo root", vim.log.levels.ERROR)
    return
  end

  -- Ensure parent directories
  ensure_dir(string.format("%s/%s", p.worktrees_root, p.repo_key))

  -- Create worktree with retry on lock
  local function add_worktree()
    local rc, _o, e = exec_git({ "worktree", "add", "-b", p.branch, p.worktree_path, base }, root)
    if rc ~= 0 then
      local em = tostring(e or "")
      if em:lower():find("lock") then
        jitter_sleep(200)
        rc, _o, e = exec_git({ "worktree", "add", "-b", p.branch, p.worktree_path, base }, root)
      end
    end
    return rc, e
  end

  local rc, e = add_worktree()
  if rc ~= 0 then
    notify("git worktree add failed: " .. tostring(e or ""), vim.log.levels.ERROR)
    return
  end

  -- Open tab + terminal
  open_session_tab(M.config, {
    id = id,
    name = slug,
    provider = provider,
    worktree_path = p.worktree_path,
    branch = p.branch,
    repo_root = root,
  })
end

-- Placeholder for abort
function M.abort_current()
  M._ensure_setup()
  local tab = vim.api.nvim_get_current_tabpage()
  local sess = M._state.sessions_by_tab[tab]
  if not sess then
    notify("no active session in this tab", vim.log.levels.WARN)
    return
  end
  if sess.term_job_id and sess.term_job_id > 0 then
    pcall(vim.fn.jobstop, sess.term_job_id)
  end
end

-- Placeholder for cleanup
function M.cleanup()
  M._ensure_setup()
  -- Best-effort cleanup for current repo's worktrees root
  local root, _ = repo_root()
  if not root then
    notify("not in a git repo; limited cleanup only runs within a repo", vim.log.levels.WARN)
    return
  end
  local id = session_id() -- seed RNG for jitter
  local p = compute_paths(root, "x", "x", id, M.config)
  local base_dir = string.format("%s/%s", p.worktrees_root, p.repo_key)
  local entries = vim.fn.globpath(base_dir, "*", false, true)
  -- Build set of active worktrees listed by git
  local code, out, _e = exec_git({ "worktree", "list" }, root)
  local active = {}
  if code == 0 then
    for line in tostring(out or ""):gmatch("[^\n]+") do
      local path = vim.trim(line:match("^([^%s]+)"))
      if path and path ~= "" then active[abspath(path)] = true end
    end
  end
  for _, path in ipairs(entries) do
    if vim.loop.fs_stat(path) and vim.loop.fs_stat(path).type == "directory" then
      local ap = abspath(path)
      if active[ap] then
        -- Remove via git
        local rc, _o2, e2 = exec_git({ "worktree", "remove", "--force", ap }, root)
        if rc ~= 0 then
          -- retry on lock
          if tostring(e2 or ""):lower():find("lock") then
            jitter_sleep(200)
            exec_git({ "worktree", "remove", "--force", ap }, root)
          end
        end
      else
        -- Not tracked by git; delete directory
        pcall(vim.fn.delete, ap, "rf")
      end
    end
  end
  exec_git({ "worktree", "prune", "--verbose" }, root)
  notify("cleanup completed")
end

-- Public helper for completion of :LLMSession provider
function M.complete_session(arglead)
  local items = provider_names()
  if not arglead or arglead == "" then
    return items
  end
  local res = {}
  for _, name in ipairs(items) do
    if name:find("^" .. vim.pesc(arglead)) then
      table.insert(res, name)
    end
  end
  return res
end

-- expose limited test helpers (after local functions are defined)
M._test = {
  sanitize_slug = sanitize_slug,
  session_id = session_id,
  is_path_inside = is_path_inside,
}

return M
