#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: push_worktree.sh --worktree <dir> [--commit-message <msg>]

Options:
  --worktree        作業対象の worktree パス
  --commit-message  変更が未コミットの場合に使うコミットメッセージ
USAGE
}

WORKTREE_DIR=""
COMMIT_MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree)
      WORKTREE_DIR="$2"
      shift 2
      ;;
    --commit-message)
      COMMIT_MESSAGE="$2"
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

if [[ -z "$WORKTREE_DIR" ]]; then
  usage
  exit 1
fi

if ! git -C "$WORKTREE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git worktree: $WORKTREE_DIR" >&2
  exit 1
fi

BRANCH="$(git -C "$WORKTREE_DIR" rev-parse --abbrev-ref HEAD)"

if [[ -z "$(git -C "$WORKTREE_DIR" status --porcelain)" ]]; then
  echo "push_skipped=1"
  exit 0
fi

git -C "$WORKTREE_DIR" add -A
if [[ -z "$COMMIT_MESSAGE" ]]; then
  COMMIT_MESSAGE="chore: update (${BRANCH})"
fi
git -C "$WORKTREE_DIR" commit -m "$COMMIT_MESSAGE"

if ! git -C "$WORKTREE_DIR" rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  echo "No upstream configured for branch: $BRANCH" >&2
  exit 1
fi

git -C "$WORKTREE_DIR" push
echo "pushed=1"
