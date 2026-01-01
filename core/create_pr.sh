#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create_pr.sh --repo <repo_dir> --worktree <dir> --pr-yml <path>
                    [--branch <name>] [--base <branch>] [--commit-message <msg>] [--draft]

Options:
  --repo            Gitリポジトリのルートパス
  --worktree        worktree のパス
  --pr-yml          PR情報のYAML（title/body）ファイル
  --branch          ブランチ名（省略時は worktree の現在ブランチ）
  --base            ベースブランチ（省略時は origin/HEAD -> main の順で推定）
  --commit-message  変更が未コミットの場合に使うコミットメッセージ
  --draft           Draft PRとして作成
USAGE
}

REPO_DIR=""
WORKTREE_DIR=""
PR_YML=""
BRANCH=""
BASE_BRANCH=""
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
    --pr-yml)
      PR_YML="$2"
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

if [[ -z "$REPO_DIR" || -z "$WORKTREE_DIR" || -z "$PR_YML" ]]; then
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

if [[ ! -f "$PR_YML" ]]; then
  echo "pr.yml not found: $PR_YML" >&2
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

TMP_BODY=""
cleanup() {
  if [[ -n "$TMP_BODY" && -f "$TMP_BODY" ]]; then
    rm -f "$TMP_BODY"
  fi
}
trap cleanup EXIT

TMP_BODY="$(mktemp)"
PR_TITLE="$(
  python3 - "$PR_YML" "$TMP_BODY" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
text = path.read_text()
lines = text.splitlines()

def parse_simple_yaml(lines):
    data = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            i += 1
            continue
        if line.startswith((" ", "\t")):
            i += 1
            continue
        if ":" not in line:
            i += 1
            continue
        key, rest = line.split(":", 1)
        key = key.strip()
        rest = rest.strip()
        if rest in ("|", "|-", ">", ">-"):
            i += 1
            block = []
            while i < len(lines):
                l = lines[i]
                if l.startswith((" ", "\t")):
                    block.append(l[1:] if l.startswith(" ") else l.lstrip("\t"))
                    i += 1
                    continue
                if l == "":
                    if i + 1 < len(lines) and lines[i + 1].startswith((" ", "\t")):
                        block.append("")
                        i += 1
                        continue
                break
            data[key] = "\n".join(block).rstrip("\n")
            continue
        if (rest.startswith('"') and rest.endswith('"')) or (rest.startswith("'") and rest.endswith("'")):
            rest = rest[1:-1]
        data[key] = rest
        i += 1
    return data

data = parse_simple_yaml(lines)
title = data.get("title", "").strip()
body = data.get("body", "").rstrip()

if not title or not body:
    print("", end="")
    out_path.write_text("")
    sys.exit(0)

out_path.write_text(body + "\n")
print(title)
PY
)"

if [[ -z "$PR_TITLE" ]]; then
  echo "Failed to read title/body from pr.yml: $PR_YML" >&2
  exit 1
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
  echo "pr_skipped=1"
  exit 0
fi

git -C "$WORKTREE_DIR" push -u origin "$BRANCH"

PR_ARGS=(pr create --base "$BASE_BRANCH" --head "$BRANCH" --title "$PR_TITLE" --body-file "$TMP_BODY")
if [[ $DRAFT -eq 1 ]]; then
  PR_ARGS+=(--draft)
fi

PR_URL="$(GH_PROMPT_DISABLED=1 gh "${PR_ARGS[@]}")"
echo "pr_url=$PR_URL"
