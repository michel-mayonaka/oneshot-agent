#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${1:?usage: summarize_run.sh <run_dir>}"
EVENTS="$RUN_DIR/logs/events.jsonl"
TIMELOG="$RUN_DIR/logs/stderr_and_time.txt"
PROMPT="$RUN_DIR/prompts/prompt.txt"
PROMPT_STATS="$RUN_DIR/prompts/prompt_stats.txt"
LASTMSG="$RUN_DIR/logs/last_message.md"
SKILLS_USED="$RUN_DIR/prompts/skills_used.txt"

OUT="$RUN_DIR/report.md"

# ---- helpers ----
have() { command -v "$1" >/dev/null 2>&1; }

# usage抽出（jqがあれば精度高く）
USAGE_JSON="{}"
if [[ -f "$EVENTS" ]] && have jq; then
  # 最後のturn.completedのusageを採用
  USAGE_JSON="$(jq -c 'select(.type=="turn.completed") | .usage' "$EVENTS" | tail -n 1 || true)"
  [[ -n "$USAGE_JSON" ]] || USAGE_JSON="{}"
fi

# time -p 抽出（real/user/sys）
REAL_TIME=""
USER_TIME=""
SYS_TIME=""
if [[ -f "$TIMELOG" ]]; then
  REAL_TIME="$(grep -E '^real ' "$TIMELOG" | tail -n 1 | awk '{print $2}' || true)"
  USER_TIME="$(grep -E '^user ' "$TIMELOG" | tail -n 1 | awk '{print $2}' || true)"
  SYS_TIME="$(grep -E '^sys '  "$TIMELOG" | tail -n 1 | awk '{print $2}' || true)"
fi

# 分表記（real）の計算
TIME_REAL_DISPLAY="N/A"
if [[ -n "${REAL_TIME:-}" ]]; then
  REAL_MIN="$(awk 'BEGIN{printf "%.2f", rt/60}' rt="$REAL_TIME" 2>/dev/null || true)"
  if [[ -n "$REAL_MIN" ]]; then
    TIME_REAL_DISPLAY="${REAL_MIN}min (${REAL_TIME}s)"
  else
    TIME_REAL_DISPLAY="${REAL_TIME}s"
  fi
fi

# git差分（git repoなら）
GIT_ROOT=""
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_ROOT="$(git rev-parse --show-toplevel)"
fi

BRANCH=""
COMMIT=""
STATUS_SHORT=""
DIFF_NAMESTAT=""
if [[ -n "$GIT_ROOT" ]]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  COMMIT="$(git rev-parse --short HEAD 2>/dev/null || true)"
  STATUS_SHORT="$(git status --porcelain 2>/dev/null || true)"
  # 「このrunで何が変わったか」を見る用途：直近状態の差分
  DIFF_NAMESTAT="$(git diff --name-status 2>/dev/null || true)"
fi

# last_message 要約（先頭だけ）。無ければ worklog.md / worklog.txt をフォールバックとして使う。
LASTMSG_HEAD=""
if [[ -f "$LASTMSG" ]]; then
  LASTMSG_HEAD="$(sed -n '1,60p' "$LASTMSG")"
elif [[ -f "$RUN_DIR/logs/worklog.md" ]]; then
  LASTMSG="$RUN_DIR/logs/worklog.md"
  LASTMSG_HEAD="$(sed -n '1,60p' "$LASTMSG")"
elif [[ -f "$RUN_DIR/logs/worklog.txt" ]]; then
  LASTMSG="$RUN_DIR/logs/worklog.txt"
  LASTMSG_HEAD="$(sed -n '1,60p' "$LASTMSG")"
fi

# prompt ハッシュ（改ざん検知/参照用）
PROMPT_SHA=""
if [[ -f "$PROMPT" ]]; then
  PROMPT_SHA="$(shasum -a 256 "$PROMPT" | awk '{print $1}')"
fi

# 不具合っぽい行（軽くgrep）
ERROR_SNIPPET=""
if [[ -f "$TIMELOG" ]]; then
  ERROR_SNIPPET="$(grep -Ei 'error|exception|failed|traceback' "$TIMELOG" | tail -n 30 || true)"
fi

# usage整形（jqが無い時は空でもOK）
IN_TOKENS=""
OUT_TOKENS=""
TOTAL_TOKENS=""
if have jq; then
  IN_TOKENS="$(printf '%s' "$USAGE_JSON" | jq -r '.input_tokens // empty' 2>/dev/null || true)"
  OUT_TOKENS="$(printf '%s' "$USAGE_JSON" | jq -r '.output_tokens // empty' 2>/dev/null || true)"
  TOTAL_TOKENS="$(printf '%s' "$USAGE_JSON" | jq -r '.total_tokens // empty' 2>/dev/null || true)"
fi

# ---- write report ----
cat > "$OUT" <<EOF
# Summary Report / サマリーレポート

## Conclusion / 結論
- Status: $( [[ -n "$ERROR_SNIPPET" ]] && echo "⚠️ has errors/warnings" || echo "✅ no obvious errors in stderr" )
- Next action: fix the top 1-3 issues and rerun with the same prompt hash.

## Run Metadata / 実行メタデータ
- run_dir: \`${RUN_DIR}\`
- prompt_sha256: \`${PROMPT_SHA}\`
- time_real: ${TIME_REAL_DISPLAY:-N/A} (user ${USER_TIME:-N/A}s / sys ${SYS_TIME:-N/A}s)
- tokens: in=${IN_TOKENS:-N/A}, out=${OUT_TOKENS:-N/A}, total=${TOTAL_TOKENS:-N/A}
- skills: $( [[ -f "$SKILLS_USED" ]] && paste -sd"," "$SKILLS_USED" || echo "N/A" )

## Git Context / Git コンテキスト
- branch: ${BRANCH:-N/A}
- commit: ${COMMIT:-N/A}
- dirty_files:
$( [[ -n "$STATUS_SHORT" ]] && printf '```text\n%s\n```\n' "$STATUS_SHORT" || echo "- (clean or not a git repo)" )

- diff_name_status:
$( [[ -n "$DIFF_NAMESTAT" ]] && printf '```text\n%s\n```\n' "$DIFF_NAMESTAT" || echo "- (no diff or not a git repo)" )

## Prompt (first 80 lines) / プロンプト（先頭80行）
$( [[ -f "$PROMPT" ]] && printf '```text\n%s\n```\n' "$(sed -n '1,80p' "$PROMPT")" || echo "- (missing prompt.txt)" )

## Prompt Stats / プロンプト統計
$( [[ -f "$PROMPT_STATS" ]] && printf '```text\n%s\n```\n' "$(cat "$PROMPT_STATS")" || echo "- (missing prompts/prompt_stats.txt)" )

## Output (last_message or worklog head) / 出力（最終メッセージ or 作業ログ先頭）
$( [[ -n "$LASTMSG_HEAD" ]] && printf '```markdown\n%s\n```\n' "$LASTMSG_HEAD" || echo "- (no output captured)" )

## Errors / Warnings (stderr tail grep) / エラー・警告（stderr 抜粋）
$( [[ -n "$ERROR_SNIPPET" ]] && printf '```text\n%s\n```\n' "$ERROR_SNIPPET" || echo "- (none detected)" )

## Artifacts / 生成物
- events: $( [[ -f "$EVENTS" ]] && echo "\`logs/events.jsonl\`" || echo "N/A" )
- worklog: $( [[ -f "$RUN_DIR/logs/worklog.md" ]] && echo "\`logs/worklog.md\`" || [[ -f "$RUN_DIR/logs/worklog.txt" ]] && echo "\`logs/worklog.txt\`" || echo "N/A" )
- commands: $( [[ -f "$RUN_DIR/logs/worklog.commands.md" ]] && echo "\`logs/worklog.commands.md\`" || echo "N/A" )
- commands_json: $( [[ -f "$RUN_DIR/logs/commands.jsonl" ]] && echo "\`logs/commands.jsonl\`" || echo "N/A" )
- stderr/time: $( [[ -f "$TIMELOG" ]] && echo "\`logs/stderr_and_time.txt\`" || echo "N/A" )
- skills_used: $( [[ -f "$SKILLS_USED" ]] && echo "\`prompts/skills_used.txt\`" || echo "N/A" )
- prompt_stats: $( [[ -f "$PROMPT_STATS" ]] && echo "\`prompts/prompt_stats.txt\`" || echo "N/A" )
EOF

echo "generated: $OUT"
