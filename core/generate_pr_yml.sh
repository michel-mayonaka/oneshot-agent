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
```

Notes:
- Do not change heading order or labels.
- No URLs inside the body. If necessary, write URLs as plain text.
- Keep the title concise, one line.
- Use the provided job name in the template as-is.

----- DIFF NAME STATUS -----
EOF
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

echo "generated: $OUT_YML"
