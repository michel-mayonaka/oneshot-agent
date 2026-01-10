#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: create_worktree.sh --repo <repo_dir> --run-id <id> --job-name <name> [--base <branch>] [--worktree-root <dir>] [--worklogs-root <dir>]

Options:
  --repo          Gitリポジトリのルートパス
  --run-id        run_id（例: 20250101-010203-12345）
  --job-name      job名（yml名など）
  --base          ベースブランチ（省略時は現在のブランチ）
  --worktree-root worktree作成先のルート（省略時は <repo_dir>/worklogs）
  --worklogs-root 互換用（worktree-rootの別名）
USAGE
}

REPO_DIR=""
RUN_ID=""
JOB_NAME=""
BASE_BRANCH=""
WORKTREE_ROOT=""
WORKLOGS_ROOT=""

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
    --job-name)
      JOB_NAME="$2"
      shift 2
      ;;
    --base)
      BASE_BRANCH="$2"
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

if [[ -z "$REPO_DIR" || -z "$RUN_ID" || -z "$JOB_NAME" ]]; then
  usage
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repo: $REPO_DIR" >&2
  exit 1
fi

if [[ -z "$WORKTREE_ROOT" ]]; then
  if [[ -n "$WORKLOGS_ROOT" ]]; then
    WORKTREE_ROOT="$WORKLOGS_ROOT"
  else
    WORKTREE_ROOT="$REPO_DIR/worklogs"
  fi
fi

sanitize_branch() {
  local name="$1"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  name="$(printf '%s' "$name" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "$name"
}

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="$(git -C "$REPO_DIR" symbolic-ref --short -q HEAD || true)"
  if [[ -z "$BASE_BRANCH" || "$BASE_BRANCH" == "HEAD" ]]; then
    BASE_BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD || true)"
  fi
  if [[ -z "$BASE_BRANCH" || "$BASE_BRANCH" == "HEAD" ]]; then
    BASE_BRANCH="main"
  fi
fi

SAFE_JOB="$(sanitize_branch "$JOB_NAME")"
if [[ -z "$SAFE_JOB" ]]; then
  SAFE_JOB="job"
fi
BRANCH_NAME="${SAFE_JOB}-${RUN_ID}"

if git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Branch already exists: $BRANCH_NAME" >&2
  exit 1
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_ROOT/$RUN_ID"
if [[ -e "$WORKTREE_DIR" ]]; then
  echo "Worktree dir already exists: $WORKTREE_DIR" >&2
  exit 1
fi
git -C "$REPO_DIR" worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "$BASE_BRANCH"
WORKTREE_ENV_SCRIPT="$ROOT_DIR/core/prepare_worktree_env.sh"
if [[ -x "$WORKTREE_ENV_SCRIPT" ]]; then
  if ! "$WORKTREE_ENV_SCRIPT" --repo "$REPO_DIR" --worktree "$WORKTREE_DIR"; then
    echo "WARN: prepare_worktree_env failed: $WORKTREE_ENV_SCRIPT" >&2
  fi
else
  echo "WARN: prepare_worktree_env.sh not found: $WORKTREE_ENV_SCRIPT" >&2
fi

echo "worktree_dir=$WORKTREE_DIR"
echo "branch=$BRANCH_NAME"
echo "base_branch=$BASE_BRANCH"
