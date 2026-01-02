#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: fetch_issue.sh --repo <repo_dir> --issue <number_or_url> --out <path>

Options:
  --repo   Gitリポジトリのルートパス
  --issue  Issue番号またはURL
  --out    出力先（issue.yml）
USAGE
}

REPO_DIR=""
ISSUE_REF=""
OUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --issue)
      ISSUE_REF="$2"
      shift 2
      ;;
    --out)
      OUT_PATH="$2"
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

if [[ -z "$REPO_DIR" || -z "$ISSUE_REF" || -z "$OUT_PATH" ]]; then
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

ISSUE_JSON="$(
  cd "$REPO_DIR" && GH_PROMPT_DISABLED=1 gh issue view "$ISSUE_REF" --json title,body,labels,assignees,milestone,url
)"

ISSUE_JSON="$ISSUE_JSON" python3 - "$OUT_PATH" <<'PY'
import json
import os
import sys

out_path = sys.argv[1]
data = json.loads(os.environ.get("ISSUE_JSON", "{}"))

title = data.get("title", "").strip()
body = data.get("body", "")
labels = [l.get("name", "") for l in data.get("labels", []) if l.get("name")]
assignees = [a.get("login", "") for a in data.get("assignees", []) if a.get("login")]
milestone = ""
if isinstance(data.get("milestone"), dict):
    milestone = data["milestone"].get("title", "")
issue_url = data.get("url", "")

def quote_scalar(value: str) -> str:
    escaped = value.replace('"', '\\"')
    return f'"{escaped}"'

lines = []
lines.append(f"title: {quote_scalar(title)}")
lines.append("body: |")
for line in body.splitlines():
    lines.append(f"  {line}")
if not body:
    lines.append("  ")
if labels:
    lines.append("labels:")
    for item in labels:
        lines.append(f"  - {item}")
else:
    lines.append("labels: []")
if assignees:
    lines.append("assignees:")
    for item in assignees:
        lines.append(f"  - {item}")
else:
    lines.append("assignees: []")
lines.append(f"milestone: {quote_scalar(milestone)}")
lines.append(f"issue_url: {quote_scalar(issue_url)}")

with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines).rstrip("\n") + "\n")
PY
