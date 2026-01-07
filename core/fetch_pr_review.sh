#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: fetch_pr_review.sh --repo <repo_dir> --pr <number_or_url> --pr-out <path> --review-out <path>

Options:
  --repo        Gitリポジトリのルートパス
  --pr          PR番号またはURL
  --pr-out      出力先（pr.yml）
  --review-out  出力先（レビューコメント/レビュー本文）
USAGE
}

REPO_DIR=""
PR_REF=""
PR_OUT=""
REVIEW_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --pr)
      PR_REF="$2"
      shift 2
      ;;
    --pr-out)
      PR_OUT="$2"
      shift 2
      ;;
    --review-out)
      REVIEW_OUT="$2"
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

if [[ -z "$REPO_DIR" || -z "$PR_REF" || -z "$PR_OUT" || -z "$REVIEW_OUT" ]]; then
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

PR_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh pr view "$PR_REF" \
    --json number,title,body,url,author,baseRefName,headRefName,headRefOid,headRepository,headRepositoryOwner
)"

REMOTE_URL="$(
  git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true
)"
if [[ -z "$REMOTE_URL" ]]; then
  FIRST_REMOTE="$(git -C "$REPO_DIR" remote | head -n 1 || true)"
  if [[ -n "$FIRST_REMOTE" ]]; then
    REMOTE_URL="$(git -C "$REPO_DIR" remote get-url "$FIRST_REMOTE" 2>/dev/null || true)"
  fi
fi

read -r PR_NUMBER BASE_OWNER BASE_REPO < <(
  PR_JSON="$PR_JSON" REMOTE_URL="$REMOTE_URL" python3 - <<'PY'
import json
import os
from urllib.parse import urlparse

def parse_owner_repo(url: str) -> tuple[str, str]:
    if not url:
        return ("", "")
    if "@" in url and ":" in url and not url.startswith(("http://", "https://")):
        path = url.split(":", 1)[1]
    else:
        path = urlparse(url).path
    path = path.strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = path.split("/")
    if len(parts) >= 2:
        return (parts[0], parts[1])
    return ("", "")

pr = json.loads(os.environ.get("PR_JSON", "{}"))
base_owner, base_name = parse_owner_repo(pr.get("url", ""))
if not base_owner or not base_name:
    base_owner, base_name = parse_owner_repo(os.environ.get("REMOTE_URL", ""))
number = pr.get("number", "")
print(f"{number}\t{base_owner}\t{base_name}")
PY
)

if [[ -z "$PR_NUMBER" || -z "$BASE_OWNER" || -z "$BASE_REPO" ]]; then
  echo "Failed to read base repo info from gh pr view." >&2
  exit 1
fi

COMMENTS_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh api --paginate "repos/$BASE_OWNER/$BASE_REPO/pulls/$PR_NUMBER/comments"
)"

REVIEWS_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh api --paginate "repos/$BASE_OWNER/$BASE_REPO/pulls/$PR_NUMBER/reviews"
)"

ISSUE_COMMENTS_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh api --paginate "repos/$BASE_OWNER/$BASE_REPO/issues/$PR_NUMBER/comments"
)"

PR_JSON="$PR_JSON" COMMENTS_JSON="$COMMENTS_JSON" REVIEWS_JSON="$REVIEWS_JSON" ISSUE_COMMENTS_JSON="$ISSUE_COMMENTS_JSON" \
  BASE_OWNER="$BASE_OWNER" BASE_REPO="$BASE_REPO" \
  python3 - "$PR_OUT" "$REVIEW_OUT" <<'PY'
import json
import os
import sys
from datetime import datetime
from urllib.parse import urlparse

pr_out = sys.argv[1]
review_out = sys.argv[2]
pr = json.loads(os.environ.get("PR_JSON", "{}"))
comments = json.loads(os.environ.get("COMMENTS_JSON", "[]"))
reviews = json.loads(os.environ.get("REVIEWS_JSON", "[]"))
issue_comments = json.loads(os.environ.get("ISSUE_COMMENTS_JSON", "[]"))
env_base_owner = os.environ.get("BASE_OWNER", "")
env_base_repo = os.environ.get("BASE_REPO", "")


def parse_owner_repo(url: str) -> tuple[str, str]:
    if not url:
        return ("", "")
    if "@" in url and ":" in url and not url.startswith(("http://", "https://")):
        path = url.split(":", 1)[1]
    else:
        path = urlparse(url).path
    path = path.strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = path.split("/")
    if len(parts) >= 2:
        return (parts[0], parts[1])
    return ("", "")


def quote_scalar(value: str) -> str:
    escaped = value.replace('"', '\\"')
    return f'"{escaped}"'


def fmt_dt(value: str) -> str:
    return value or ""


# pr.yml
lines = []
lines.append(f"number: {pr.get('number', '')}")
lines.append(f"title: {quote_scalar((pr.get('title') or '').strip())}")
lines.append(f"url: {quote_scalar(pr.get('url', ''))}")
lines.append(f"author: {quote_scalar(((pr.get('author') or {}).get('login')) or '')}")
base_owner, base_name = parse_owner_repo(pr.get("url", ""))
if not base_owner or not base_name:
    base_owner, base_name = (env_base_owner, env_base_repo)
lines.append(f"base_repo: {quote_scalar(f'{base_owner}/{base_name}'.strip('/'))}")
lines.append(f"base_ref: {quote_scalar(pr.get('baseRefName', ''))}")
head_repo = pr.get("headRepository") or {}
head_owner = (pr.get("headRepositoryOwner") or {}).get("login", "")
head_name = head_repo.get("name", "")
lines.append(f"head_repo: {quote_scalar(f'{head_owner}/{head_name}'.strip('/'))}")
lines.append(f"head_ref: {quote_scalar(pr.get('headRefName', ''))}")
lines.append(f"head_sha: {quote_scalar(pr.get('headRefOid', ''))}")
lines.append("body: |")
body = pr.get("body") or ""
for line in body.splitlines():
    lines.append(f"  {line}")
if not body:
    lines.append("  ")

with open(pr_out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines).rstrip("\n") + "\n")

# review output
review_lines = []
review_lines.append("# PRレビューコメント")
review_lines.append("")
review_lines.append(f"- number: {pr.get('number', '')}")
review_lines.append(f"- title: {(pr.get('title') or '').strip()}")
review_lines.append(f"- url: {pr.get('url', '')}")
review_lines.append(f"- base: {base_owner}/{base_name}@{pr.get('baseRefName', '')}")
review_lines.append(f"- head: {head_owner}/{head_name}@{pr.get('headRefName', '')} ({pr.get('headRefOid', '')})")
review_lines.append("")
review_lines.append("## 行コメント")

if comments:
    for c in comments:
        path = c.get("path", "")
        line = c.get("line") or c.get("original_line") or ""
        user = (c.get("user") or {}).get("login", "")
        created = fmt_dt(c.get("created_at", ""))
        body = (c.get("body") or "").rstrip()
        loc = f"{path}:{line}" if line != "" else path
        review_lines.append(f"- {loc} / {user} / {created}")
        if body:
            for bl in body.splitlines():
                review_lines.append(f"  {bl}")
        else:
            review_lines.append("  (本文なし)")
else:
    review_lines.append("- （なし）")

review_lines.append("")
review_lines.append("## レビュー")
if reviews:
    for r in reviews:
        user = (r.get("user") or {}).get("login", "")
        state = r.get("state", "")
        submitted = fmt_dt(r.get("submitted_at", ""))
        body = (r.get("body") or "").rstrip()
        review_lines.append(f"- {state} / {user} / {submitted}")
        if body:
            for bl in body.splitlines():
                review_lines.append(f"  {bl}")
        else:
            review_lines.append("  (本文なし)")
else:
    review_lines.append("- （なし）")

review_lines.append("")
review_lines.append("## PRコメント（会話）")
if issue_comments:
    for c in issue_comments:
        user = (c.get("user") or {}).get("login", "")
        created = fmt_dt(c.get("created_at", ""))
        body = (c.get("body") or "").rstrip()
        review_lines.append(f"- {user} / {created}")
        if body:
            for bl in body.splitlines():
                review_lines.append(f"  {bl}")
        else:
            review_lines.append("  (本文なし)")
else:
    review_lines.append("- （なし）")

with open(review_out, "w", encoding="utf-8") as f:
    f.write("\n".join(review_lines).rstrip("\n") + "\n")
PY
