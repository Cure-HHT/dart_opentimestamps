# Git Hooks

This directory contains git hooks to maintain code quality.

## Prerequisites

The hooks require `dart` to be available in your PATH. If you installed Flutter/Dart, make sure it's in your shell's PATH:

```bash
# Add to your ~/.bashrc, ~/.zshrc, or equivalent
export PATH="$PATH:/path/to/flutter/bin"
```

## Available Hooks

### pre-commit
- Runs `dart format` on staged Dart files and re-stages them
- Runs `dart analyze --fatal-infos` and fails if there are any issues

### pre-push
- Runs `tool/test.sh` to execute all tests
- Fails the push if any tests fail

## Installation

Run the install script to copy hooks to `.git/hooks/`:

```bash
./hooks/install.sh
```

## Skipping Hooks

If you need to skip hooks temporarily (not recommended):

```bash
# Skip pre-commit hook
git commit --no-verify

# Skip pre-push hook
git push --no-verify
```

## Uninstalling

To remove the hooks:

```bash
rm .git/hooks/pre-commit
rm .git/hooks/pre-push
```
