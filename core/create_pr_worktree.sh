#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create_pr_worktree.sh --repo <repo_dir> --run-id <id> --job-name <name> --pr <number_or_url>
                             [--worktree-root <dir>] [--worklogs-root <dir>]

Options:
  --repo          Gitリポジトリのルートパス
  --run-id        run_id（例: 20250101-010203-12345）
  --job-name      job名（yml名など）
  --pr            PR番号またはURL
  --worktree-root worktree作成先のルート（省略時は <repo_dir>/worklogs）
  --worklogs-root 互換用（worktree-rootの別名）
USAGE
}

REPO_DIR=""
RUN_ID=""
JOB_NAME=""
PR_REF=""
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
    --pr)
      PR_REF="$2"
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

if [[ -z "$REPO_DIR" || -z "$RUN_ID" || -z "$JOB_NAME" || -z "$PR_REF" ]]; then
  usage
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not a git repo: $REPO_DIR" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh command not found. Install GitHub CLI first." >&2
  exit 1
fi

if [[ -z "$WORKTREE_ROOT" ]]; then
  if [[ -n "$WORKLOGS_ROOT" ]]; then
    WORKTREE_ROOT="$WORKLOGS_ROOT"
  else
    WORKTREE_ROOT="$REPO_DIR/worklogs"
  fi
fi

sanitize_token() {
  local name="$1"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  name="$(printf '%s' "$name" | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "$name"
}

PR_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh pr view "$PR_REF" \
    --json number,headRefName,headRefOid,headRepository,headRepositoryOwner,baseRefName,baseRepository
)"

read -r PR_NUMBER HEAD_REF HEAD_SHA HEAD_REPO_OWNER HEAD_REPO_NAME BASE_REF BASE_REPO_OWNER BASE_REPO_NAME < <(
  PR_JSON="$PR_JSON" python3 - <<'PY'
import json
import os

pr = json.loads(os.environ.get("PR_JSON", "{}"))
number = pr.get("number", "")
head_ref = pr.get("headRefName", "")
head_sha = pr.get("headRefOid", "")
head_repo = pr.get("headRepository") or {}
head_owner = (pr.get("headRepositoryOwner") or {}).get("login", "")
head_repo_name = head_repo.get("name", "")
base_ref = pr.get("baseRefName", "")
base_repo = pr.get("baseRepository") or {}
base_owner = (base_repo.get("owner") or {}).get("login", "")
base_repo_name = base_repo.get("name", "")
print(f"{number}\t{head_ref}\t{head_sha}\t{head_owner}\t{head_repo_name}\t{base_ref}\t{base_owner}\t{base_repo_name}")
PY
)

if [[ -z "$PR_NUMBER" || -z "$HEAD_REF" || -z "$HEAD_REPO_OWNER" || -z "$HEAD_REPO_NAME" ]]; then
  echo "Failed to read PR info from gh pr view." >&2
  exit 1
fi

HEAD_REPO_FULL="$HEAD_REPO_OWNER/$HEAD_REPO_NAME"
HEAD_REMOTE_URL="https://github.com/$HEAD_REPO_FULL.git"

REMOTE_NAME="pr-${PR_NUMBER}-$(sanitize_token "$HEAD_REPO_OWNER")"
if [[ -z "$REMOTE_NAME" ]]; then
  REMOTE_NAME="pr-${PR_NUMBER}-head"
fi

if git -C "$REPO_DIR" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  EXISTING_URL="$(git -C "$REPO_DIR" remote get-url "$REMOTE_NAME")"
  if [[ "$EXISTING_URL" != "$HEAD_REMOTE_URL" ]]; then
    REMOTE_NAME="${REMOTE_NAME}-$RANDOM"
  fi
fi

if ! git -C "$REPO_DIR" remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git -C "$REPO_DIR" remote add "$REMOTE_NAME" "$HEAD_REMOTE_URL"
fi

git -C "$REPO_DIR" fetch "$REMOTE_NAME" "$HEAD_REF"

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_ROOT/$RUN_ID"
if [[ -e "$WORKTREE_DIR" ]]; then
  echo "Worktree dir already exists: $WORKTREE_DIR" >&2
  exit 1
fi

BRANCH_IN_USE=0
if git -C "$REPO_DIR" worktree list --porcelain | awk -v b="refs/heads/$HEAD_REF" '$1=="branch" && $2==b {found=1} END{exit found?0:1}'; then
  BRANCH_IN_USE=1
fi

if [[ $BRANCH_IN_USE -eq 1 ]]; then
  echo "Branch already checked out in another worktree: $HEAD_REF" >&2
  exit 1
fi

if git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$HEAD_REF"; then
  git -C "$REPO_DIR" worktree add "$WORKTREE_DIR" "$HEAD_REF"
else
  git -C "$REPO_DIR" worktree add -b "$HEAD_REF" "$WORKTREE_DIR" "$REMOTE_NAME/$HEAD_REF"
fi

if git -C "$REPO_DIR" show-ref --verify --quiet "refs/remotes/$REMOTE_NAME/$HEAD_REF"; then
  git -C "$WORKTREE_DIR" branch --set-upstream-to "$REMOTE_NAME/$HEAD_REF" "$HEAD_REF" >/dev/null 2>&1 || true
fi

echo "worktree_dir=$WORKTREE_DIR"
echo "branch=$HEAD_REF"
if [[ -n "$BASE_REF" ]]; then
  echo "base_branch=$BASE_REF"
fi
