local git = require('llm_legion.git_helpers')

local function exec(cmd, cwd)
  if vim.system then
    local res = vim.system(cmd, { cwd = cwd }):wait()
    return res.code or 1, res.stdout or '', res.stderr or ''
  else
    local out = vim.fn.system(cmd)
    return vim.v.shell_error, out or '', ''
  end
end

describe('landing helpers', function()
  it('detects dirty and stashes safely', function()
    if vim.fn.executable('git') ~= 1 then
      pending('git not available in test env')
      return
    end
    local tmp = vim.fn.tempname()
    assert(vim.fn.mkdir(tmp, 'p') == 1)
    local function cleanup()
      pcall(vim.fn.delete, tmp, 'rf')
    end
    finally(cleanup)

    assert.are.equal(0, exec({ 'git', 'init' }, tmp))
    -- configure identity for commit
    assert.are.equal(0, exec({ 'git', 'config', 'user.email', 'test@example.com' }, tmp))
    assert.are.equal(0, exec({ 'git', 'config', 'user.name', 'Test' }, tmp))

    -- initial commit
    local f = tmp .. '/a.txt'
    assert(vim.fn.writefile({ 'hello' }, f) == 0)
    assert.are.equal(0, exec({ 'git', 'add', 'a.txt' }, tmp))
    assert.are.equal(0, exec({ 'git', 'commit', '-m', 'init' }, tmp))

    -- dirty change
    assert(vim.fn.writefile({ 'hello', 'world' }, f) == 0)
    local dirty, _ = git.is_dirty(tmp)
    assert.is_true(dirty)

    local ok = ({ git.stash_push('test', tmp) })[1]
    assert.is_true(ok)

    local dirty2, _ = git.is_dirty(tmp)
    assert.is_false(dirty2)

    local ok2 = ({ git.stash_pop_safe(tmp) })[1]
    assert.is_true(ok2)
  end)
end)

