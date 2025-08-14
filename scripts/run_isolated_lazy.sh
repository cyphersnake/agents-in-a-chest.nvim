#!/usr/bin/env bash
set -euo pipefail

# Run Neovim in an isolated environment, loading this plugin via lazy.nvim if available.
# Usage: scripts/run_isolated_lazy.sh [PLUGIN_DIR] [SANDBOX_REPO]
# - PLUGIN_DIR defaults to repository root of this script
# - SANDBOX_REPO if provided, nvim starts with that as the CWD
#
# Optional env:
# - LAZY: path to an existing lazy.nvim checkout (no network needed)

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

plugin_dir="${1:-${repo_root}}"
sandbox_repo="${2:-}"

# Isolated XDG locations so nothing leaks into your real config
base="$(mktemp -d -t agents-in-a-chest-nvim-XXXXXX)"
export XDG_DATA_HOME="${base}/data"
export XDG_STATE_HOME="${base}/state"
export XDG_CACHE_HOME="${base}/cache"
mkdir -p "${XDG_DATA_HOME}" "${XDG_STATE_HOME}" "${XDG_CACHE_HOME}"

# Provide PLUGIN_DIR to init.lua
export PLUGIN_DIR="${plugin_dir}"

config_dir="${base}/config"
mkdir -p "${config_dir}"
init_lua="${config_dir}/init.lua"

cat >"${init_lua}" <<'LUA'
-- Isolated init.lua for agents-in-a-chest.nvim QA
vim.opt.runtimepath:append(vim.env.PLUGIN_DIR)

-- Try to use lazy.nvim if provided via $LAZY; fall back to rtp direct.
local lazypath = vim.env.LAZY
if lazypath and lazypath ~= '' then
  if vim.uv.fs_stat(lazypath) then
    vim.opt.rtp:prepend(lazypath)
    local ok, lazy = pcall(require, 'lazy')
    if ok then
      lazy.setup({ { dir = vim.env.PLUGIN_DIR, name = 'agents-in-a-chest.nvim' } }, {})
    else
      vim.notify('[agents-in-a-chest QA] lazy.nvim found but failed to load; using direct rtp', vim.log.levels.WARN)
    end
  else
    vim.notify('[agents-in-a-chest QA] LAZY path not found; using direct rtp', vim.log.levels.WARN)
  end
else
  vim.notify('[agents-in-a-chest QA] LAZY not set; using direct rtp', vim.log.levels.WARN)
end

-- Minimal UI/behavior to keep things predictable
vim.o.swapfile = false
vim.o.hidden = true
vim.o.number = true

-- Configure the plugin for offline QA: use `sh` provider that exits.
local ok, llm = pcall(require, 'agents_in_a_chest')
if not ok then
  vim.schedule(function()
    vim.notify('[agents-in-a-chest QA] failed to require plugin', vim.log.levels.ERROR)
  end)
else
  llm.setup({
    providers = {
      claude = { cmd = 'sh', args = { '-c', 'echo ok; sleep 0.2' } },
    },
  })
end

-- Handy command to kick a quick session
vim.api.nvim_create_user_command('LLMQuick', function()
  require('agents_in_a_chest').session_cmd({ 'claude', '--name', 'qa' })
end, {})

LUA

echo "Isolated NVIM base: ${base}"
echo "Plugin dir: ${plugin_dir}"
if [[ -n "${LAZY:-}" ]]; then echo "Using lazy from: ${LAZY}"; fi

pushd "${sandbox_repo:-${repo_root}}" >/dev/null || true

# Launch Neovim with isolated config; keep it interactive for manual QA
exec nvim -u "${init_lua}" -n -i NONE

