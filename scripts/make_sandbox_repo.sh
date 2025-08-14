#!/usr/bin/env bash
set -euo pipefail

# Create a fresh sandbox git repo with an initial commit.
# Usage: scripts/make_sandbox_repo.sh [TARGET_DIR]

target_dir="${1:-}"
if [[ -z "${target_dir}" ]]; then
  target_dir="$(mktemp -d -t agents-in-a-chest-sandbox-XXXXXX)"
else
  mkdir -p "${target_dir}"
fi

git -C "${target_dir}" init -q
git -C "${target_dir}" config user.email "sandbox@example.com"
git -C "${target_dir}" config user.name "Sandbox User"
echo "hello" > "${target_dir}/README.md"
git -C "${target_dir}" add README.md
git -C "${target_dir}" commit -q -m "chore: initial sandbox commit"

echo "Sandbox repo ready: ${target_dir}"
echo "Tip: cd ${target_dir} && git worktree list"

