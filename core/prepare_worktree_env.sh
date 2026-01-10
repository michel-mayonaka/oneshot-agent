#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: prepare_worktree_env.sh --repo <repo_dir> --worktree <worktree_dir> [--mode <copy|link|install>] [--sync-dirs <paths>]

Options:
  --repo       元リポジトリのルートパス
  --worktree   作成済み worktree のパス
  --mode       同期モード（copy/link/install。省略時は ONESHOT_WORKTREE_ENV_MODE or copy）
  --sync-dirs  同期対象のパス（カンマ or 空白区切り。省略時は ONESHOT_WORKTREE_SYNC_DIRS or tools/shellspec）
USAGE
}

REPO_DIR=""
WORKTREE_DIR=""
MODE=""
SYNC_DIRS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --worktree)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --sync-dirs)
      SYNC_DIRS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPO_DIR" || -z "$WORKTREE_DIR" ]]; then
  usage
  exit 1
fi

if [[ -z "$MODE" ]]; then
  MODE="${ONESHOT_WORKTREE_ENV_MODE:-copy}"
fi

case "$MODE" in
  copy|link|install) ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 1
    ;;
esac

if [[ -z "$SYNC_DIRS" ]]; then
  SYNC_DIRS="${ONESHOT_WORKTREE_SYNC_DIRS:-tools/shellspec}"
fi

normalize_entry() {
  printf '%s' "$1" | sed -E 's#^/+##; s#/$##'
}

install_shellspec() {
  local install_script="$WORKTREE_DIR/tools/install_shellspec.sh"
  if [[ ! -x "$install_script" ]]; then
    echo "WARN: install_shellspec.sh not found: $install_script" >&2
    return 1
  fi
  if ! (cd "$WORKTREE_DIR" && bash "$install_script"); then
    echo "WARN: failed to install ShellSpec" >&2
    return 1
  fi
  return 0
}

copy_path() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if command -v rsync >/dev/null 2>&1; then
    if [[ -d "$src" ]]; then
      mkdir -p "$dest"
      rsync -a "$src/" "$dest/"
    else
      rsync -a "$src" "$dest"
    fi
    return 0
  fi
  cp -R "$src" "$dest"
}

link_path() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
}

sync_entry() {
  local entry="$1"
  local src="$REPO_DIR/$entry"
  local dest="$WORKTREE_DIR/$entry"
  if [[ -e "$dest" ]]; then
    return 0
  fi
  if [[ "$MODE" == "install" && "$entry" == "tools/shellspec" ]]; then
    install_shellspec || return 0
    return 0
  fi
  if [[ -e "$src" ]]; then
    if [[ "$MODE" == "link" ]]; then
      if ! link_path "$src" "$dest"; then
        echo "WARN: failed to link: $dest" >&2
      fi
    else
      if ! copy_path "$src" "$dest"; then
        echo "WARN: failed to copy: $dest" >&2
      fi
    fi
    return 0
  fi
  if [[ "$entry" == "tools/shellspec" ]]; then
    install_shellspec || true
    return 0
  fi
  echo "WARN: sync source not found: $src" >&2
}

SYNC_DIRS="${SYNC_DIRS//,/ }"
for raw_entry in $SYNC_DIRS; do
  entry="$(normalize_entry "$raw_entry")"
  [[ -z "$entry" ]] && continue
  if [[ "$entry" == *".."* ]]; then
    echo "WARN: skip sync path with .. : $entry" >&2
    continue
  fi
  sync_entry "$entry"
done
