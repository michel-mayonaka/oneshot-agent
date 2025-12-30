#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create-pr.sh --repo <repo_dir> --worktree <dir> [--branch <name>] [--base <branch>]
                    [--title <title>] [--body-file <path>] [--commit-message <msg>] [--draft]

Options:
  --repo            Gitリポジトリのルートパス
  --worktree        worktree のパス
  --branch          ブランチ名（省略時は worktree の現在ブランチ）
  --base            ベースブランチ（省略時は origin/HEAD -> main の順で推定）
  --title           PRタイトル（省略時は最新コミットの件名）
  --body-file       PR本文ファイル（省略時は空）
  --commit-message  変更が未コミットの場合に使うコミットメッセージ
  --draft           Draft PRとして作成
USAGE
}

REPO_DIR=""
WORKTREE_DIR=""
BRANCH=""
BASE_BRANCH=""
PR_TITLE=""
PR_BODY_FILE=""
COMMIT_MESSAGE=""
DRAFT=0

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
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --title)
      PR_TITLE="$2"
      shift 2
      ;;
    --body-file)
      PR_BODY_FILE="$2"
      shift 2
      ;;
    --commit-message)
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --draft)
      DRAFT=1
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

if [[ -z "$REPO_DIR" || -z "$WORKTREE_DIR" ]]; then
  usage
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repo: $REPO_DIR" >&2
  exit 1
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
  echo "Worktree dir not found: $WORKTREE_DIR" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh command not found. Install GitHub CLI first." >&2
  exit 1
fi

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git -C "$WORKTREE_DIR" rev-parse --abbrev-ref HEAD)"
fi

if [[ -z "$BASE_BRANCH" ]]; then
  base_ref="$(git -C "$REPO_DIR" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  BASE_BRANCH="${base_ref#origin/}"
  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="main"
  fi
fi

if [[ -z "$PR_TITLE" ]]; then
  PR_TITLE="$(git -C "$WORKTREE_DIR" log -1 --pretty=%s)"
fi

if [[ -z "$PR_BODY_FILE" ]]; then
  PR_BODY_FILE=""
fi

if [[ -n "$(git -C "$WORKTREE_DIR" status --porcelain)" ]]; then
  git -C "$WORKTREE_DIR" add -A
  if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="docs: update (${BRANCH})"
  fi
  git -C "$WORKTREE_DIR" commit -m "$COMMIT_MESSAGE"
fi

if [[ "$(git -C "$WORKTREE_DIR" rev-list --count "${BASE_BRANCH}..${BRANCH}")" == "0" ]]; then
  echo "No commits to open PR (base=${BASE_BRANCH}, branch=${BRANCH})" >&2
  exit 1
fi

git -C "$WORKTREE_DIR" push -u origin "$BRANCH"

PR_ARGS=(pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "$PR_TITLE")
if [[ -n "$PR_BODY_FILE" && -f "$PR_BODY_FILE" ]]; then
  PR_ARGS+=(--body-file "$PR_BODY_FILE")
else
  PR_ARGS+=(--body "")
fi
if [[ $DRAFT -eq 1 ]]; then
  PR_ARGS+=(--draft)
fi

PR_URL="$(GH_PROMPT_DISABLED=1 gh "${PR_ARGS[@]}")"
echo "pr_url=$PR_URL"
