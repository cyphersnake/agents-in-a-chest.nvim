local G = {}

local function run_blocking(cmd, opts)
  -- Avoid vim.system():wait() when in fast event contexts (e.g., timers)
  local cwd = (opts or {}).cwd
  if cwd and cwd ~= '' then
    local st = vim.loop.fs_stat(cwd)
    if not (st and st.type == 'directory') then
      return 1, "", string.format("ENOENT: cwd not found: %s", tostring(cwd))
    end
  end
  if vim.system and not vim.in_fast_event() then
    local proc = vim.system(cmd, { cwd = cwd })
    local res = proc:wait()
    return res.code or 1, res.stdout or "", res.stderr or ""
  else
    local out = vim.fn.system(cmd)
    local code = vim.v.shell_error
    return code, out or "", ""
  end
end

function G.exec_git(args, cwd)
  local cmd = { "git" }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  return run_blocking(cmd, { cwd = cwd })
end

function G.is_dirty(cwd)
  local code, out, _ = G.exec_git({ "status", "--porcelain" }, cwd)
  if code ~= 0 then return false, "git status failed" end
  return vim.trim(out) ~= "", nil
end

function G.stash_push(id, cwd)
  local msg = string.format("llm-autosave-%s", tostring(id))
  local code, out, err = G.exec_git({ "stash", "push", "-u", "-k", "-m", msg }, cwd)
  return code == 0, out, err, msg
end

function G.stash_pop_safe(cwd)
  local code, out, err = G.exec_git({ "stash", "pop" }, cwd)
  return code == 0, out, err
end

function G.get_commit_message(sha, cwd)
  local code, out, err = G.exec_git({ "log", "-1", "--pretty=%B", sha }, cwd)
  if code ~= 0 then return nil, err ~= "" and err or out end
  return vim.trim(out), nil
end

function G.rev_parse(sym, cwd)
  local c, o, e = G.exec_git({ "rev-parse", sym }, cwd)
  if c ~= 0 then return nil, e ~= "" and e or o end
  return vim.trim(o), nil
end

function G.branch_exists(name, cwd)
  local c, _o, _e = G.exec_git({ "rev-parse", "--verify", "--quiet", "refs/heads/" .. name }, cwd)
  return c == 0
end

function G.get_default_branch(cwd)
  -- Try origin/HEAD symbolic ref first
  local c1, o1, _e1 = G.exec_git({ "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" }, cwd)
  if c1 == 0 then
    local ref = vim.trim(o1 or "") -- e.g., origin/main
    local b = ref:match("origin/(.+)$")
    if b and b ~= "" then return b end
  end
  -- Try parsing `git remote show origin`
  local c2, o2, _e2 = G.exec_git({ "remote", "show", "origin" }, cwd)
  if c2 == 0 then
    local head = tostring(o2 or ""):match("HEAD branch:%s*([%w%._%-%/]+)")
    if head and head ~= "" then return vim.trim(head) end
  end
  -- Prefer common names
  if G.branch_exists("main", cwd) then return "main" end
  if G.branch_exists("master", cwd) then return "master" end
  -- Fallback to current branch if not HEAD
  local c3, o3, _e3 = G.exec_git({ "rev-parse", "--abbrev-ref", "HEAD" }, cwd)
  if c3 == 0 then
    local cur = vim.trim(o3 or "")
    if cur ~= "" and cur ~= "HEAD" then return cur end
  end
  return "main"
end

function G.remote_branch_exists(remote, branch, cwd)
  local c, o, _e = G.exec_git({ "ls-remote", "--heads", remote, branch }, cwd)
  if c ~= 0 then return false end
  return vim.trim(o or "") ~= ""
end

function G.ensure_switch_branch(branch, cwd)
  local c1, _o1, e1 = G.exec_git({ "switch", branch }, cwd)
  if c1 == 0 then return true end
  local em = tostring(e1 or "")
  if em:match("invalid reference") or em:match("unknown revision") or em:match("did not match any file%(s%) known to git") then
    -- try to create tracking branch from origin/<branch>
    if G.remote_branch_exists("origin", branch, cwd) then
      local c2, _o2, _e2 = G.exec_git({ "switch", "-c", branch, "--track", string.format("origin/%s", branch) }, cwd)
      return c2 == 0
    end
  end
  return false, e1
end

return G
