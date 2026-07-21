#!/bin/sh
# Configure git hooks for this clone (and all its worktrees).
# Run once per clone after `git clone`.
#
# core.hooksPath is written to the clone's common config, so every
# worktree of this clone inherits it without re-running setup.
#
# Note: this is unrelated to hooks/install.sh, which copies the
# pre-existing hooks/pre-commit and hooks/pre-push Dart-tooling scripts
# straight into .git/hooks/. That flow and this one are mutually
# exclusive — core.hooksPath (set below) takes priority over .git/hooks/
# for any hook git already knows how to look up by name, so running both
# installers leaves hooks/install.sh's copies dormant. Use this script;
# hooks/ is left untouched by this change.

set -e

# Run from the repo root so `pre-commit install-hooks` finds
# .pre-commit-config.yaml regardless of where the script was invoked.
cd "$(git rev-parse --show-toplevel)"

if ! command -v pre-commit >/dev/null 2>&1; then
  cat >&2 <<'MSG'
Error: pre-commit not found on PATH.

Install via one of:
  pipx install pre-commit         # recommended (https://pypa.github.io/pipx/)
  brew install pre-commit         # macOS
  pip install --user pre-commit   # cross-platform

Docs: https://pre-commit.com/#install

After installation, re-run scripts/setup.sh
MSG
  exit 1
fi

git config core.hooksPath .githooks

# Pre-populate hook environments so the first commit doesn't pay the
# install latency.
pre-commit install-hooks

cat <<'MSG'
Setup complete:
  - core.hooksPath = .githooks
  - hook environments cached for first commit

Hooks run on every commit (and gitleaks also on push), in this clone
and any of its worktrees. To bypass once (NOT recommended): commit
with --no-verify. To run hooks manually against the whole tree:
pre-commit run --all-files
MSG
