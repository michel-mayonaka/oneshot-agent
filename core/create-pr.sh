#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create-pr.sh --repo <repo_dir> --worktree <dir> [--branch <name>] [--base <branch>]
                    [--title <title>] [--body-file <path>] [--report <path>] [--heading <name>]
                    [--commit-message <msg>] [--draft]

Options:
  --repo            Gitリポジトリのルートパス
  --worktree        worktree のパス
  --branch          ブランチ名（省略時は worktree の現在ブランチ）
  --base            ベースブランチ（省略時は origin/HEAD -> main の順で推定）
  --title           PRタイトル（省略時は最新コミットの件名）
  --body-file       PR本文ファイル（省略時は空）
  --report          report.md から PR情報 を抽出する場合のパス
  --heading         PR情報の見出し名（省略時は「PR情報」）
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
REPORT_FILE=""
HEADING="PR情報"
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
    --report)
      REPORT_FILE="$2"
      shift 2
      ;;
    --heading)
      HEADING="$2"
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

TMP_BODY=""
cleanup() {
  if [[ -n "$TMP_BODY" && -f "$TMP_BODY" ]]; then
    rm -f "$TMP_BODY"
  fi
}
trap cleanup EXIT

if [[ -n "$REPORT_FILE" && -f "$REPORT_FILE" && -z "$PR_BODY_FILE" ]]; then
  TMP_BODY="$(mktemp)"
  PR_TITLE_FROM_REPORT="$(
    python3 - "$REPORT_FILE" "$HEADING" "$TMP_BODY" <<'PY'
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
heading = sys.argv[2]
out_path = Path(sys.argv[3])

text = report_path.read_text()
lines = text.splitlines()

blocks = []
current = None
def is_heading(line):
    line = line.strip()
    if line == f"## {heading}":
        return True
    if line in (f"**{heading}**", f"**{heading}** "):
        return True
    return False

for line in lines:
    if is_heading(line):
        if current is not None:
            blocks.append(current)
        current = []
        continue
    if current is not None:
        if line.startswith("## "):
            blocks.append(current)
            current = None
            continue
        current.append(line)
if current is not None:
    blocks.append(current)

def parse_block(block):
    title = ""
    body_lines = []
    in_body = False
    for line in block:
        if line.startswith("タイトル:"):
            title = line.replace("タイトル:", "", 1).strip()
            continue
        if line.startswith("本文:") or line.startswith("説明:"):
            body_lines.append(line.split(":", 1)[1].strip())
            in_body = True
            continue
        if in_body:
            body_lines.append(line)
    if not body_lines:
        body_lines = block
    body = "\n".join(body_lines).strip()
    return title, body

def is_placeholder(title, body):
    bad = ["<", ">", "簡潔なPRタイトル", "注意:"]
    if not title:
        return True
    if any(x in title for x in bad):
        return True
    if any(x in body for x in bad):
        return True
    return False

selected_title = ""
selected_body = ""
for block in blocks[::-1]:
    title, body = parse_block(block)
    if is_placeholder(title, body):
        continue
    selected_title = title
    selected_body = body
    break

if selected_body:
    out_path.write_text(selected_body + "\n")
    print(selected_title)
else:
    out_path.write_text("")
    print("")
PY
  )"

  if [[ -n "$PR_TITLE_FROM_REPORT" ]]; then
    if [[ -z "$PR_TITLE" ]]; then
      PR_TITLE="$PR_TITLE_FROM_REPORT"
    fi
    if [[ -s "$TMP_BODY" ]]; then
      PR_BODY_FILE="$TMP_BODY"
    fi
  else
    rm -f "$TMP_BODY"
    TMP_BODY=""
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
