#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: remove-worktree.sh --repo <repo_dir> (--run-id <id> | --path <worktree_dir>) [--worktree-root <dir>] [--worklogs-root <dir>] [--force]

Options:
  --repo          Gitリポジトリのルートパス
  --run-id        run_id（worklogs/<run_id> を対象にする）
  --path          worktree のパスを直接指定
  --worktree-root run_id から解決する場合のルート（省略時は <repo_dir>/worklogs）
  --worklogs-root 互換用（worktree-rootの別名）
  --force         worktree が未クリーンでも削除する
USAGE
}

REPO_DIR=""
RUN_ID=""
WORKTREE_DIR=""
WORKTREE_ROOT=""
WORKLOGS_ROOT=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --path)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --worklogs-root)
      WORKLOGS_ROOT="$2"
      shift 2
      ;;
    --worktree-root)
      WORKTREE_ROOT="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift 1
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

if [[ -z "$REPO_DIR" ]]; then
  usage
  exit 1
fi

if [[ -z "$RUN_ID" && -z "$WORKTREE_DIR" ]]; then
  usage
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repo: $REPO_DIR" >&2
  exit 1
fi

if [[ -n "$RUN_ID" ]]; then
  if [[ -z "$WORKTREE_ROOT" ]]; then
    if [[ -n "$WORKLOGS_ROOT" ]]; then
      WORKTREE_ROOT="$WORKLOGS_ROOT"
    else
      WORKTREE_ROOT="$REPO_DIR/worklogs"
    fi
  fi
  WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
fi

if [[ -z "$WORKTREE_DIR" ]]; then
  echo "worktree dir is empty" >&2
  exit 1
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
  echo "Worktree dir not found: $WORKTREE_DIR" >&2
  exit 1
fi

REMOVE_ARGS=()
if [[ $FORCE -eq 1 ]]; then
  REMOVE_ARGS=(--force)
fi

git -C "$REPO_DIR" worktree remove "${REMOVE_ARGS[@]}" "$WORKTREE_DIR"
echo "removed_worktree=$WORKTREE_DIR"
