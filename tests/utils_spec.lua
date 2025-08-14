local eq = assert.are.same

describe('utils', function()
  it('sanitizes slug to allowed set', function()
    local m = require('agents_in_a_chest')
    local s = m._test.sanitize_slug('Hello World/Привет?* Foo__bar')
    -- lowercased, non-matching replaced with '-'
    eq('hello-world--foo__bar', s)
  end)

  it('session id format', function()
    local m = require('agents_in_a_chest')
    local id = m._test.session_id()
    assert.is_true(id:match('^%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d%-%x%x%x%x%x$') ~= nil)
  end)

  it('path inside guard', function()
    local m = require('agents_in_a_chest')
    local inside = m._test.is_path_inside('/a/b/c', '/a/b')
    local outside = m._test.is_path_inside('/a/bc', '/a/b')
    assert.is_true(inside)
    assert.is_false(outside)
  end)
end)
