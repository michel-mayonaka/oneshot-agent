#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create-worktree.sh --repo <repo_dir> --run-id <id> --spec-name <name> [--base <branch>] [--worktree-root <dir>] [--worklogs-root <dir>]

Options:
  --repo          Gitリポジトリのルートパス
  --run-id        run_id（例: 20250101-010203-12345）
  --spec-name     spec名（yml名など）
  --base          ベースブランチ（省略時は現在のブランチ）
  --worktree-root worktree作成先のルート（省略時は <repo_dir>/worktrees）
  --worklogs-root 互換用（worktree-rootの別名）
USAGE
}

REPO_DIR=""
RUN_ID=""
SPEC_NAME=""
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
    --spec-name)
      SPEC_NAME="$2"
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

if [[ -z "$REPO_DIR" || -z "$RUN_ID" || -z "$SPEC_NAME" ]]; then
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
    WORKTREE_ROOT="$REPO_DIR/worktrees"
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

SAFE_SPEC="$(sanitize_branch "$SPEC_NAME")"
if [[ -z "$SAFE_SPEC" ]]; then
  SAFE_SPEC="spec"
fi
BRANCH_NAME="${SAFE_SPEC}-${RUN_ID}"

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

echo "worktree_dir=$WORKTREE_DIR"
echo "branch=$BRANCH_NAME"
echo "base_branch=$BASE_BRANCH"
