#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$ROOT_DIR/tools/shellspec"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to install ShellSpec" >&2
  exit 1
fi

if [[ -d "$DEST/.git" ]]; then
  echo "ShellSpec already installed. Updating..."
  if git -C "$DEST" fetch --all --tags --prune; then
    git -C "$DEST" checkout master
    git -C "$DEST" pull --ff-only
    echo "updated: $DEST"
  else
    echo "WARN: update failed; using existing ShellSpec copy." >&2
  fi
  exit 0
fi

if [[ -d "$DEST" ]]; then
  echo "ShellSpec directory exists without git metadata. Using existing copy: $DEST"
  exit 0
fi

rm -rf "$DEST"
git clone https://github.com/shellspec/shellspec.git "$DEST"

echo "installed: $DEST"
