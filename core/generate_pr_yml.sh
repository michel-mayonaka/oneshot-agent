#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${1:?usage: generate_pr_yml.sh <run_dir>}"
WORKLOG_MD="$RUN_DIR/worklog.md"
WORKLOG_FALLBACK="$RUN_DIR/logs/worklog.md"
WORKTREE_DIR="$RUN_DIR/worktree"
OUT_YML="$RUN_DIR/pr.yml"
RUN_ONESHOT_LOG="$RUN_DIR/logs/run-oneshot.log"

if [[ ! -f "$WORKLOG_MD" ]]; then
  if [[ -f "$WORKLOG_FALLBACK" ]]; then
    WORKLOG_MD="$WORKLOG_FALLBACK"
  else
    echo "worklog.md not found in: $RUN_DIR" >&2
    exit 1
  fi
fi

if [[ ! -d "$WORKTREE_DIR" ]]; then
  echo "worktree dir not found in: $RUN_DIR" >&2
  exit 1
fi

if ! git -C "$WORKTREE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "worktree is not a git repo: $WORKTREE_DIR" >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  exit 1
fi

INPUTS_FILE="$RUN_DIR/inputs/inputs.txt"
ISSUE_INPUT_PATH=""
ISSUE_NUMBER=""
ISSUE_URL=""

if [[ -f "$INPUTS_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    key="${line%%=*}"
    val="${line#*=}"
    if [[ "$key" == "issue" ]]; then
      ISSUE_INPUT_PATH="$val"
      break
    fi
  done < "$INPUTS_FILE"
fi

if [[ -n "$ISSUE_INPUT_PATH" ]]; then
  if [[ "$ISSUE_INPUT_PATH" != /* && -n "${ONESHOT_AGENT_ROOT:-}" ]]; then
    ISSUE_INPUT_PATH="$ONESHOT_AGENT_ROOT/$ISSUE_INPUT_PATH"
  fi
  if [[ ! -f "$ISSUE_INPUT_PATH" ]]; then
    ISSUE_INPUT_PATH=""
  fi
fi

if [[ -n "$ISSUE_INPUT_PATH" ]]; then
  {
    IFS= read -r ISSUE_NUMBER
    IFS= read -r ISSUE_URL
  } < <(python3 - "$ISSUE_INPUT_PATH" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
issue_url = ""
issue_number = ""
for line in text.splitlines():
    if line.startswith("issue_url:"):
        issue_url = line.split(":", 1)[1].strip().strip('"').strip("'")
    if line.startswith("issue_number:"):
        issue_number = line.split(":", 1)[1].strip().strip('"').strip("'")
if not issue_number and issue_url:
    m = re.search(r"/issues/(\\d+)", issue_url)
    if m:
        issue_number = m.group(1)
print(issue_number)
print(issue_url)
PY
  )
fi

JOB_NAME=""
if [[ -f "$RUN_ONESHOT_LOG" ]]; then
  JOB_NAME="$(awk -F= '/^name=/{print $2; exit}' "$RUN_ONESHOT_LOG")"
fi
if [[ -z "$JOB_NAME" ]]; then
  JOB_NAME="$(basename "$(dirname "$RUN_DIR")")"
fi

MODEL="${ONESHOT_PR_MODEL:-gpt-5.2}"
DIFF_MAX_LINES="${ONESHOT_PR_DIFF_MAX_LINES:-2000}"

DIFF_NAMESTAT="$(git -C "$WORKTREE_DIR" diff --name-status)"
DIFF_STAT="$(git -C "$WORKTREE_DIR" diff --stat)"
DIFF_BODY="$(git -C "$WORKTREE_DIR" diff | sed -n "1,${DIFF_MAX_LINES}p")"

{
  cat <<'EOF'
You are a developer assistant.

Task:
- Read the git diff summary and the worklog content.
- Produce a PR title and body in YAML.

Output requirements:
- Output ONLY valid YAML.
- YAML keys must be: title, body.
- body must be a Markdown string that follows the exact PR template below.
- Use Japanese.

PR body template (must follow exactly):
```markdown
# ジョブ名
- <job-name>

# 概要
- <何を/なぜやったかを1-2行>

# 変更点
- <主な変更を箇条書き>

# 影響範囲
- <影響がある範囲。なければ「なし」>

# 確認コマンド
- <実行したコマンド。未実行なら「未実行」>

# 関連Issue
- <Closes #123 または なし>
```

Notes:
- Do not change heading order or labels.
- No URLs inside the body. If necessary, write URLs as plain text.
- Keep the title concise, one line.
- Use the provided job name in the template as-is.
- If issue number is provided, write "Closes #<number>" under "関連Issue".
- If issue number is not provided, write "なし" under "関連Issue".
- Use issue number (e.g. #123), not issue URL.

----- DIFF NAME STATUS -----
EOF
  if [[ -n "$ISSUE_NUMBER" || -n "$ISSUE_URL" ]]; then
    echo "----- ISSUE INFO -----"
    if [[ -n "$ISSUE_NUMBER" ]]; then
      echo "Issue number: ${ISSUE_NUMBER}"
    fi
    if [[ -n "$ISSUE_URL" ]]; then
      echo "Issue url: ${ISSUE_URL}"
    fi
    echo "----- ISSUE INFO END -----"
  fi
  echo "Job name: ${JOB_NAME}"
  echo ""
  echo "----- DIFF NAME STATUS -----"
  printf '%s\n' "$DIFF_NAMESTAT"
  cat <<'EOF'
----- DIFF STAT -----
EOF
  printf '%s\n' "$DIFF_STAT"
  cat <<'EOF'
----- DIFF (TRUNCATED) -----
EOF
  printf '%s\n' "$DIFF_BODY"
  cat <<'EOF'
----- WORKLOG START -----
EOF
  cat "$WORKLOG_MD"
  cat <<'EOF'
----- WORKLOG END -----
EOF
} | codex exec --skip-git-repo-check --model "$MODEL" > "$OUT_YML"

if [[ -n "$ISSUE_NUMBER" ]]; then
  python3 - "$OUT_YML" "$ISSUE_NUMBER" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
issue_number = sys.argv[2].strip()
if not issue_number:
    sys.exit(0)

text = path.read_text(encoding="utf-8")
lines = text.splitlines()

def find_body_block(lines):
    for i, line in enumerate(lines):
        if re.match(r"^body:\\s*(\\||\\|-|>|>-)\\s*$", line):
            start = i + 1
            indent = None
            body_lines = []
            j = start
            while j < len(lines):
                l = lines[j]
                if l.startswith((" ", "\\t")):
                    if indent is None:
                        m = re.match(r"^(\\s+)", l)
                        indent = m.group(1) if m else "  "
                    if l.startswith(indent):
                        body_lines.append(l[len(indent):])
                    else:
                        body_lines.append(l.lstrip())
                    j += 1
                    continue
                if l == "" and j + 1 < len(lines) and lines[j + 1].startswith((" ", "\\t")):
                    body_lines.append("")
                    j += 1
                    continue
                break
            return i, start, j, indent or "  ", body_lines
    return None

info = find_body_block(lines)
if not info:
    sys.exit(0)

_, start, end, indent, body_lines = info
body_text = "\n".join(body_lines)
closing_re = re.compile(rf"(?i)\\b(?:closes|fixes|resolves)\\s+[^\\n]*#?{re.escape(issue_number)}\\b")
if closing_re.search(body_text):
    sys.exit(0)

header = "# 関連Issue"
section_idx = None
for i, line in enumerate(body_lines):
    if line.strip() == header:
        section_idx = i
        break

if section_idx is None:
    if body_lines and body_lines[-1].strip() != "":
        body_lines.append("")
    body_lines.append(header)
    body_lines.append(f"- Closes #{issue_number}")
else:
    j = section_idx + 1
    while j < len(body_lines) and not body_lines[j].startswith("# "):
        j += 1
    section_lines = body_lines[section_idx + 1 : j]
    replaced = False
    for k, line in enumerate(section_lines):
        if re.search(r"なし", line):
            body_lines[section_idx + 1 + k] = f"- Closes #{issue_number}"
            replaced = True
            break
    if not replaced:
        body_lines.insert(j, f"- Closes #{issue_number}")

new_body = [indent + l if l != "" else indent for l in body_lines]
new_lines = lines[:start] + new_body + lines[end:]
path.write_text("\n".join(new_lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")
PY
fi

echo "generated: $OUT_YML"
