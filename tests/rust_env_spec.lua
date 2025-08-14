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

describe('rust env', function()
  if vim.fn.executable('git') ~= 1 then
    pending('git not available')
    return
  end

  it('detects rust project via Cargo.toml', function()
    local dir = tmpdir()
    vim.fn.writefile({ '[package]', 'name = "demo"', 'version = "0.1.0"' }, dir .. '/Cargo.toml')
    local m = require('agents_in_a_chest')
    eq(true, m._test.is_rust_project(dir))
  end)

  it('exports CARGO_TARGET_DIR to provider for rust repos', function()
    -- init temp repo
    local dir = tmpdir()
    local rc
    rc = sys({ 'git', 'init', '-q' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'config', 'user.email', 'test@example.com' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'config', 'user.name', 'Test' }, dir)
    assert.are.equal(0, rc)
    vim.fn.writefile({ '[package]', 'name = "demo"', 'version = "0.1.0"' }, dir .. '/Cargo.toml')
    vim.fn.writefile({ 'hello' }, dir .. '/file.txt')
    rc = sys({ 'git', 'add', 'file.txt', 'Cargo.toml' }, dir)
    assert.are.equal(0, rc)
    rc = sys({ 'git', 'commit', '-m', 'init' }, dir)
    assert.are.equal(0, rc)

    -- cd into repo
    vim.cmd('cd ' .. vim.fn.fnameescape(dir))

    local out_file = dir .. '/.env_cargo_target_dir'
    -- configure plugin with provider that writes env var to repo root and exits
    local m = require('agents_in_a_chest')
    m.setup({
      providers = {
        claude = { cmd = 'sh', args = { '-c', 'printf "%s" "$CARGO_TARGET_DIR" > "$OUT"' }, env = { OUT = out_file } },
      },
      rust = { share_target_dir = true },
    })

    -- run session; should exit immediately and cleanup; env written to out_file
    m.session_cmd({ 'claude', '--name', 'rust-env' })
    vim.wait(1000)

    local contents = ''
    if vim.loop.fs_stat(out_file) then
      contents = table.concat(vim.fn.readfile(out_file), '\n')
    end
    eq(dir .. '/target', contents)
  end)
end)

