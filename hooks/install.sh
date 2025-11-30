#!/bin/bash
# Install git hooks

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GIT_DIR=$(git rev-parse --git-dir)

echo "Installing git hooks..."

# Install pre-commit hook
if [ -f "$SCRIPT_DIR/pre-commit" ]; then
  cp "$SCRIPT_DIR/pre-commit" "$GIT_DIR/hooks/pre-commit"
  chmod +x "$GIT_DIR/hooks/pre-commit"
  echo "✅ Installed pre-commit hook"
fi

# Install pre-push hook
if [ -f "$SCRIPT_DIR/pre-push" ]; then
  cp "$SCRIPT_DIR/pre-push" "$GIT_DIR/hooks/pre-push"
  chmod +x "$GIT_DIR/hooks/pre-push"
  echo "✅ Installed pre-push hook"
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Pre-commit: Formats code and runs dart analyze"
echo "Pre-push: Runs tests via tool/test.sh"
echo ""
echo "To skip hooks temporarily, use:"
echo "  git commit --no-verify"
echo "  git push --no-verify"
