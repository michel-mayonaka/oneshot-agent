#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-C <target_dir>] <prompt.txt or prompt string>

  -C DIR   Codex を実行するターゲットディレクトリ（既存リポジトリなど）。
           省略時は、このリポジトリ直下に playground/<run_id>/ を作成して使用します。
EOF
}

TARGET_DIR=""
while getopts "C:h" opt; do
  case "$opt" in
    C) TARGET_DIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  usage
  exit 1
fi

# スクリプト自身のディレクトリ（shells/）を解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
RUN_DIR="$SCRIPT_DIR/../worklogs/$RUN_ID"
mkdir -p "$RUN_DIR"

# ターゲットディレクトリ決定（デフォルトは playground/<run_id>/）
if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="$SCRIPT_DIR/../playground/$RUN_ID"
fi
mkdir -p "$TARGET_DIR"

# どこで動かしたかをメタデータとして残す
printf '%s\n' "$TARGET_DIR" > "$RUN_DIR/target_dir.txt"

PROMPT_FILE="$RUN_DIR/prompt.txt"
if [[ -f "$PROMPT" ]]; then
  cp "$PROMPT" "$PROMPT_FILE"
else
  printf "%s" "$PROMPT" > "$PROMPT_FILE"
fi

# JSONLをこのrun専用に保存（混ざらない）
{
  pushd "$TARGET_DIR" >/dev/null
  /usr/bin/time -p \
  codex exec \
    --skip-git-repo-check \
    --full-auto \
    --model gpt-5.2-codex \
    --json \
    - < "$PROMPT_FILE" \
  | tee "$RUN_DIR/events.jsonl" >/dev/null
  popd >/dev/null
} 2> "$RUN_DIR/stderr_and_time.txt"

# 作業ログ：reasoning や agent_message を時系列で Markdown 風に残す（Markdown形式）
jq -r '
  select(.type=="item.completed" and (.item.type=="reasoning" or .item.type=="agent_message"))
  | "### " + .item.type + "\n" + (.item.text // "") + "\n"
' "$RUN_DIR/events.jsonl" > "$RUN_DIR/worklog.md"

# 最終メッセージ（サマリー）を別ファイルに保存（summary_report から参照）
jq -rs '
  map(select(.type=="item.completed" and .item.type=="agent_message"))
  | if length > 0 then .[length-1].item.text else empty end
' "$RUN_DIR/events.jsonl" > "$RUN_DIR/last_message.md"

# トークン usage（最後のturn.completedを採用）
jq -c 'select(.type=="turn.completed") | .usage' "$RUN_DIR/events.jsonl" | tail -n 1 > "$RUN_DIR/usage.json"

echo "run_dir=$RUN_DIR"
echo "target_dir=$TARGET_DIR"

"$SCRIPT_DIR/summarize_run.sh" "$RUN_DIR"
