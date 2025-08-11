local eq = assert.are.same

describe('git_helpers cwd handling', function()
  it('returns error when cwd is missing without throwing', function()
    local G = require('llm_legion.git_helpers')
    local missing = vim.fn.tempname()
    -- ensure path does not exist
    if vim.loop.fs_stat(missing) then vim.fn.delete(missing, 'rf') end
    local code, out, err = G.exec_git({ 'status' }, missing)
    -- Should not crash; should return non-zero and an ENOENT message
    assert.is_true(code ~= 0)
    eq('', out or '')
    assert.is_truthy(tostring(err or ''):match('ENOENT: cwd not found'))
  end)
end)

