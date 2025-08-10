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

describe('lifecycle', function()
  if vim.fn.executable('git') ~= 1 then
    pending('git not available')
    return
  end

  it('creates, commits, removes worktree on exit', function()
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

    -- configure plugin with dummy provider
    local m = require('llm_legion')
    m.setup({
      providers = {
        claude = { cmd = 'sh', args = { '-c', 'true' } },
      },
    })

    -- run session; should exit immediately and cleanup
    m.session_cmd({ 'claude', '--name', 'test' })
    vim.wait(1000)

    -- worktree dir removed, but branch created with commit if any changes
    local _code, branches = sys({ 'git', 'for-each-ref', 'refs/heads/llm/claude/', '--format=%(refname:short)' }, dir)
    branches = vim.trim(branches or '')
    assert.is_true(branches == '' or branches:match('^llm/claude/.+') ~= nil)

    -- no lingering worktree
    local _c2, wtl = sys({ 'git', 'worktree', 'list' }, dir)
    assert.is_nil(wtl:match('%-worktrees'))
  end)
end)
