local eq = assert.are.same

local function sys(cmd, cwd)
  local out = vim.fn.system(cmd, cwd and { cwd = cwd } or nil)
  return vim.v.shell_error, out
end

local function tmpdir()
  local name = vim.fn.tempname()
  vim.fn.mkdir(name, 'p')
  return name
end

-- Find leaf worktree directories under parent/.<prefix>-worktrees/<key>/*
local function find_leaf_worktrees(parent)
  local matches = vim.fn.globpath(parent, '.*-worktrees/*/*', false, true)
  local dirs = {}
  for _, p in ipairs(matches) do
    local st = vim.loop.fs_stat(p)
    if st and st.type == 'directory' then table.insert(dirs, p) end
  end
  return dirs
end

describe('cleanup stability', function()
  if vim.fn.executable('git') ~= 1 then
    pending('git not available')
    return
  end

  it('removes leaf worktree dir after session exit', function()
    -- init temp repo
    local dir = tmpdir()
    local rc
    rc = sys({ 'git', 'init', '-q' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'config', 'user.email', 'test@example.com' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'config', 'user.name', 'Test' }, dir)
    assert.are.equal(0, rc)
    vim.fn.writefile({ 'hello' }, dir .. '/file.txt')
    rc = sys({ 'git', 'add', 'file.txt' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'commit', '-m', 'init' }, dir)
    assert.are.equal(0, rc)

    -- cd into repo
    vim.cmd('cd ' .. vim.fn.fnameescape(dir))

    -- configure plugin with dummy provider that exits immediately
    local m = require('llm_legion')
    m.setup({
      providers = {
        claude = { cmd = 'sh', args = { '-c', 'true' } },
      },
    })

    -- Before: capture any pre-existing leaf dirs under parent (should be none in tmp)
    local parent = vim.fn.fnamemodify(dir .. '/..', ':p')
    local before = find_leaf_worktrees(parent)

    -- run session; should exit quickly and trigger cleanup
    m.session_cmd({ 'claude', '--name', 'cleanup-check' })
    vim.wait(1000)

    -- After: expect no leaf dirs left behind
    local after = find_leaf_worktrees(parent)
    -- Allow that base directories may exist, but no leaf (session) dirs
    eq({}, after)
  end)
end)

