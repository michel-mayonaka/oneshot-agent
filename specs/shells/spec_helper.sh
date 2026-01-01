#!/usr/bin/env bash
set -euo pipefail

SPEC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SPEC_ROOT/.." && pwd)"

export SPEC_ROOT
export REPO_ROOT

export PATH="$SPEC_ROOT/support/bin:$PATH"
export LC_ALL=C

setup_tmp() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

cleanup_tmp() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

make_file() {
  local path="$1"
  local content="${2:-}"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
}
