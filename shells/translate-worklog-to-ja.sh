#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${1:?usage: translate-worklog-to-ja.sh <run_dir>}"
WORKLOG_MD="$RUN_DIR/worklog.md"
OUT_JA="$RUN_DIR/worklog.ja.md"

if [[ ! -f "$WORKLOG_MD" ]]; then
  echo "worklog.md not found in: $RUN_DIR" >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found in PATH" >&2
  exit 1
fi

MODEL="${ONESHOT_TRANSLATE_MODEL:-gpt-5.2}"

{
  cat <<'EOF'
You are a bilingual developer assistant.

Task:
- Read the following Markdown work log.
- Translate all natural language content into clear, natural Japanese.
- Keep the Markdown structure (headings, lists, code fences) as intact as possible.
- Keep code, commands, and paths as-is (do NOT translate identifiers).

Output:
- Only the translated Markdown. Do not add extra commentary.

----- WORK LOG START -----
EOF
  cat "$WORKLOG_MD"
  cat <<'EOF'
----- WORK LOG END -----
EOF
} | codex exec --skip-git-repo-check --model "$MODEL" > "$OUT_JA"

echo "generated: $OUT_JA"
