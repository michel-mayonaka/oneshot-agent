#!/usr/bin/env bash
set -euo pipefail

PROMPT="${1:?usage: run <prompt.txt or prompt string>}"

RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
RUN_DIR="./worklogs/$RUN_ID"
mkdir -p "$RUN_DIR"

PROMPT_FILE="$RUN_DIR/prompt.txt"
if [[ -f "$PROMPT" ]]; then
  cp "$PROMPT" "$PROMPT_FILE"
else
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
fi

# JSONLをこのrun専用に保存（混ざらない）
# turn.completed に usage が入る :contentReference[oaicite:5]{index=5}
{
  /usr/bin/time -p \
  codex exec \
    --skip-git-repo-check \
    --full-auto \
    --model gpt-5.2-codex \
    --json \
    - < "$PROMPT_FILE" \
  | tee "$RUN_DIR/events.jsonl" \
  | jq -r '
      # 人間向けworklog：assistantの最終メッセージを拾う
      select(.type=="item.completed" and .item.type=="agent_message") | .item.text
    ' > "$RUN_DIR/worklog.txt"
} 2> "$RUN_DIR/stderr_and_time.txt"

# トークン usage（最後のturn.completedを採用）
jq -c 'select(.type=="turn.completed") | .usage' "$RUN_DIR/events.jsonl" | tail -n 1 > "$RUN_DIR/usage.json"

echo "run_dir=$RUN_DIR"

./summarize_run.sh "$RUN_DIR"
