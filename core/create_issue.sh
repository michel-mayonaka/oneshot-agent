#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create_issue.sh --repo <repo_dir> --issue-yml <path_or_dir>

Options:
  --repo        Gitリポジトリのルートパス
  --issue-yml   issue.yml もしくは issues/ ディレクトリ
USAGE
}

REPO_DIR=""
ISSUE_YML=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_DIR="$2"
      shift 2
      ;;
    --issue-yml)
      ISSUE_YML="$2"
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

if [[ -z "$REPO_DIR" || -z "$ISSUE_YML" ]]; then
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

issue_files=()
if [[ -d "$ISSUE_YML" ]]; then
  shopt -s nullglob
  issue_files=( "$ISSUE_YML"/*.yml "$ISSUE_YML"/*.yaml )
  shopt -u nullglob
elif [[ -f "$ISSUE_YML" ]]; then
  issue_files=( "$ISSUE_YML" )
else
  echo "issue.yml not found: $ISSUE_YML" >&2
  exit 1
fi

if [[ ${#issue_files[@]} -eq 0 ]]; then
  echo "No issue.yml files found: $ISSUE_YML" >&2
  exit 1
fi

for issue_file in "${issue_files[@]}"; do
  python3 - "$issue_file" "$REPO_DIR" <<'PY'
import os
import subprocess
import sys
import tempfile

issue_path = sys.argv[1]
repo_dir = sys.argv[2]

def parse_simple_yaml(lines):
    data = {}
    i = 0
    while i < len(lines):
        line = lines[i].rstrip("\n")
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
                l = lines[i].rstrip("\n")
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
        if rest == "":
            i += 1
            items = []
            while i < len(lines):
                l = lines[i]
                if not l.startswith((" ", "\t")):
                    break
                s = l.strip()
                if not s or s.startswith("#"):
                    i += 1
                    continue
                if s.startswith("-"):
                    item = s[1:].strip()
                    if item and item[0] in ("'", '"') and item[-1:] == item[:1]:
                        item = item[1:-1]
                    if item:
                        items.append(item)
                i += 1
            data[key] = items if items else ""
            continue
        if rest and rest[0] in ("'", '"') and rest[-1:] == rest[:1]:
            rest = rest[1:-1]
        data[key] = rest
        i += 1
    return data

def to_list(val):
    if val is None:
        return []
    if isinstance(val, list):
        return val
    if not isinstance(val, str):
        return []
    s = val.strip()
    if not s:
        return []
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return []
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    return [x.strip().strip("'\"") for x in s.split(",") if x.strip()]

lines = open(issue_path, encoding="utf-8").read().splitlines()
data = parse_simple_yaml(lines)

title = (data.get("title") or "").strip()
body = data.get("body") or ""
labels = to_list(data.get("labels"))
assignees = to_list(data.get("assignees"))
milestone = (data.get("milestone") or "").strip()

if not title:
    print(f"Missing title in issue.yml: {issue_path}", file=sys.stderr)
    sys.exit(1)
if body is None or body == "":
    print(f"Missing body in issue.yml: {issue_path}", file=sys.stderr)
    sys.exit(1)

with tempfile.NamedTemporaryFile(delete=False, mode="w", encoding="utf-8") as f:
    f.write(body + "\n")
    body_path = f.name

try:
    cmd = ["gh", "issue", "create", "--title", title, "--body-file", body_path]
    if labels:
        cmd += ["--label", ",".join(labels)]
    if assignees:
        cmd += ["--assignee", ",".join(assignees)]
    if milestone:
        cmd += ["--milestone", milestone]
    env = os.environ.copy()
    env["GH_PROMPT_DISABLED"] = "1"
    result = subprocess.run(
        cmd,
        cwd=repo_dir,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr.strip() or result.stdout.strip(), file=sys.stderr)
        sys.exit(result.returncode)
    output = result.stdout.strip()
    if output:
        print(f"issue_url={output}")
finally:
    try:
        os.remove(body_path)
    except FileNotFoundError:
        pass
PY
done
