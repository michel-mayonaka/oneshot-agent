#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [-C <target_dir>] [-s skill1,skill2] <prompt.txt or prompt string>

  -C DIR   Codex を実行するターゲットディレクトリ（既存リポジトリなど）。
           省略時は、worklogs/<run_id>/artifacts/ を作成して使用します。
  -s NAME  追加で読み込む optional skill 名（カンマ区切り可）。skills/optional/<NAME>.md を参照します。

環境変数:
  ONESHOT_SKILLS                追加で読み込む optional skill 名（カンマ区切り）。
  ONESHOT_DISABLE_GLOBAL_SKILLS グローバルskills(global/)を無効化する場合に1を設定。
  ONESHOT_MODEL                 Codex 実行モデル（未指定時は gpt-5.2）。
  ONESHOT_THINKING              reasoning.effort に渡す thinking レベル（例: low/medium/high）。
EOF
}

TARGET_DIR=""
OPTIONAL_SKILLS_CLI=()
while getopts "C:s:h" opt; do
  case "$opt" in
    C) TARGET_DIR="$OPTARG" ;;
    s)
      IFS=',' read -ra __parts <<< "$OPTARG"
      for __name in "${__parts[@]}"; do
        [[ -n "$__name" ]] && OPTIONAL_SKILLS_CLI+=("$__name")
      done
      ;;
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

# スクリプト自身のディレクトリ（core/）を解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# リポジトリルート（ONESHOT_AGENT_ROOT 必須）
: "${ONESHOT_AGENT_ROOT:?ONESHOT_AGENT_ROOT is not set}"
AGENT_ROOT="$ONESHOT_AGENT_ROOT"

RUN_ID="${ONESHOT_RUN_ID:-}"
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
fi
DEFAULT_RUNS_DIR="$AGENT_ROOT/worklogs/oneshot-exec"
RUNS_DIR="${ONESHOT_RUNS_DIR:-$DEFAULT_RUNS_DIR}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"
mkdir -p "$RUN_DIR/logs" "$RUN_DIR/prompts" "$RUN_DIR/inputs"
RUN_RUNNING_FILE="$RUN_DIR/.running"
{
  echo "pid=$$"
  echo "started_at=$(date +%Y-%m-%dT%H:%M:%S%z)"
} > "$RUN_RUNNING_FILE"
cleanup_running() { rm -f "$RUN_RUNNING_FILE"; }
trap cleanup_running EXIT

# 旧runをアーカイブ（run_oneshot経由では無効化）
if [[ -z "${ONESHOT_ARCHIVE_HANDLED:-}" ]]; then
  ARCHIVE_DIR="$RUNS_DIR/archive"
  mkdir -p "$ARCHIVE_DIR"
  shopt -s nullglob
  for d in "$RUNS_DIR"/*; do
    [[ "$d" == "$ARCHIVE_DIR" ]] && continue
    [[ "$d" == "$RUN_DIR" ]] && continue
    [[ -d "$d" ]] || continue
    [[ -f "$d/.running" ]] && continue
    base="$(basename "$d")"
    dest="$ARCHIVE_DIR/$base"
    if [[ -e "$dest" ]]; then
      ts="$(date +%Y%m%d-%H%M%S)"
      dest="$ARCHIVE_DIR/$base.$ts"
    fi
    if [[ -e "$dest" ]]; then
      dest="$ARCHIVE_DIR/$base.$RANDOM"
    fi
    mv "$d" "$dest"
  done
  shopt -u nullglob
fi

# ターゲットディレクトリ決定（デフォルトは worklogs/<run_id>/artifacts/）
if [[ -z "$TARGET_DIR" ]]; then
  TARGET_DIR="$RUN_DIR/artifacts"
fi
mkdir -p "$TARGET_DIR"

# どこで動かしたかをメタデータとして残す
printf '%s\n' "$TARGET_DIR" > "$RUN_DIR/logs/target_dir.txt"

# プロンプト（生／最終）と skills 使用状況
RAW_PROMPT_FILE="$RUN_DIR/prompts/prompt.raw.txt"
FINAL_PROMPT_FILE="$RUN_DIR/prompts/prompt.txt"
SKILLS_USED_FILE="$RUN_DIR/prompts/skills_used.txt"

if [[ -f "$SKILLS_USED_FILE" ]]; then
  : > "$SKILLS_USED_FILE"
fi

# 生プロンプトを保存
if [[ -f "$PROMPT" ]]; then
  cp "$PROMPT" "$RAW_PROMPT_FILE"
else
  printf "%s" "$PROMPT" > "$RAW_PROMPT_FILE"
fi

# skills を解決して最終プロンプトを組み立てる
GLOBAL_SKILL_FILES=()
GLOBAL_SKILLS_DIR="$AGENT_ROOT/skills/global"
if [[ -z "${ONESHOT_DISABLE_GLOBAL_SKILLS:-}" && -d "$GLOBAL_SKILLS_DIR" ]]; then
  # 全ての *.md を読み込む（存在しない場合はスキップ）
  while IFS= read -r f; do
    GLOBAL_SKILL_FILES+=("$f")
  done < <(ls "$GLOBAL_SKILLS_DIR"/*.md 2>/dev/null | sort || true)
fi

OPTIONAL_SKILL_NAMES=()
# 環境変数 ONESHOT_SKILLS
if [[ -n "${ONESHOT_SKILLS:-}" ]]; then
  IFS=',' read -ra __env_parts <<< "$ONESHOT_SKILLS"
  for __name in "${__env_parts[@]}"; do
    [[ -n "$__name" ]] && OPTIONAL_SKILL_NAMES+=("$__name")
  done
fi
# CLI -s（配列未定義でもコケないよう、一時的に set +u）
set +u
for __name in "${OPTIONAL_SKILLS_CLI[@]}"; do
  [[ -n "$__name" ]] && OPTIONAL_SKILL_NAMES+=("$__name")
done
set -u

OPTIONAL_SKILL_FILES=()
OPTIONAL_SKILLS_DIR="$AGENT_ROOT/skills/optional"
if [[ -d "$OPTIONAL_SKILLS_DIR" ]]; then
  set +u
  if [[ ${#OPTIONAL_SKILL_NAMES[@]} -gt 0 ]]; then
    for __name in "${OPTIONAL_SKILL_NAMES[@]}"; do
      __file_md="$OPTIONAL_SKILLS_DIR/${__name}.md"
      __dir="$OPTIONAL_SKILLS_DIR/${__name}"
      __file_dir="$__dir/SKILL.md"
      if [[ -f "$__file_dir" ]]; then
        OPTIONAL_SKILL_FILES+=("$__file_dir")
        if [[ -f "$__file_md" ]]; then
          echo "WARN: optional skill has both dir and md; using dir: ${__name}" >&2
        fi
      elif [[ -f "$__file_md" ]]; then
        OPTIONAL_SKILL_FILES+=("$__file_md")
      else
        echo "WARN: optional skill not found: ${__name}" >&2
      fi
    done
  fi
  set -u
fi

# skills_used.txt に記録
: > "$SKILLS_USED_FILE"
for f in "${GLOBAL_SKILL_FILES[@]}"; do
  rel="${f#"$AGENT_ROOT/"}"
  echo "$rel" >> "$SKILLS_USED_FILE"
done
set +u
for f in "${OPTIONAL_SKILL_FILES[@]}"; do
  rel="${f#"$AGENT_ROOT/"}"
  echo "$rel" >> "$SKILLS_USED_FILE"
done
set -u

# 最終プロンプトを組み立て
{
  if [[ ${#GLOBAL_SKILL_FILES[@]} -gt 0 ]]; then
    echo "# Agent Skills (global)"
    for f in "${GLOBAL_SKILL_FILES[@]}"; do
      rel="${f#"$AGENT_ROOT/"}"
      echo ""
      echo "## skill: ${rel}"
      echo ""
      cat "$f"
      echo ""
    done
    echo ""
  fi

  set +u
  if [[ ${#OPTIONAL_SKILL_FILES[@]} -gt 0 ]]; then
    echo "# Agent Skills (optional)"
    for f in "${OPTIONAL_SKILL_FILES[@]}"; do
      rel="${f#"$AGENT_ROOT/"}"
      echo ""
      echo "## skill: ${rel}"
      echo ""
      cat "$f"
      echo ""
    done
    echo ""
  fi
  set -u

  echo "# User Prompt"
  echo "----- USER PROMPT START -----"
  cat "$RAW_PROMPT_FILE"
  echo ""
  echo "----- USER PROMPT END -----"
} > "$FINAL_PROMPT_FILE"

# Codex実行オプション
MODEL="${ONESHOT_MODEL:-gpt-5.2}"
THINKING="${ONESHOT_THINKING:-}"
# bash 3.2 + set -u では空配列展開がエラーになるため、コマンド配列で組み立てる
CODEX_CMD=(codex exec --skip-git-repo-check --full-auto --model "$MODEL")
if [[ -n "$THINKING" ]]; then
  CODEX_CMD+=( -c "reasoning.effort=\"${THINKING}\"" )
fi
CODEX_CMD+=( --json - )

# JSONLをこのrun専用に保存（混ざらない）
{
  pushd "$TARGET_DIR" >/dev/null
  /usr/bin/time -p \
  "${CODEX_CMD[@]}" < "$FINAL_PROMPT_FILE" \
  | tee "$RUN_DIR/logs/events.jsonl" >/dev/null
  popd >/dev/null
} 2> "$RUN_DIR/logs/stderr_and_time.txt"

# 作業ログ：reasoning や agent_message を時系列で Markdown 風に残す（Markdown形式）
jq -r '
  select(.type=="item.completed" and (.item.type=="reasoning" or .item.type=="agent_message"))
  | "### " + .item.type + "\n" + (.item.text // "") + "\n"
' "$RUN_DIR/logs/events.jsonl" > "$RUN_DIR/logs/worklog.md"

# コマンドログ：command_execution をコマンド単位で保存
jq -c '
  select(.type=="item.completed" and .item.type=="command_execution")
  | {command:.item.command, status:.item.status, exit_code:.item.exit_code, output:.item.aggregated_output}
' "$RUN_DIR/logs/events.jsonl" > "$RUN_DIR/logs/commands.jsonl"

jq -r '
  "## Command " + (input_line_number|tostring) + "\n"
  + "- command: `" + .command + "`\n"
  + "- status: " + (.status // "") + "\n"
  + "- exit_code: " + (.exit_code|tostring) + "\n"
  + (if (.output // "") != "" then "\n```text\n" + .output + "\n```\n" else "\n" end)
' "$RUN_DIR/logs/commands.jsonl" > "$RUN_DIR/logs/worklog.commands.md"

# 最終メッセージ（サマリー）を別ファイルに保存（summary_report から参照）
jq -rs '
  map(select(.type=="item.completed" and .item.type=="agent_message"))
  | if length > 0 then .[length-1].item.text else empty end
' "$RUN_DIR/logs/events.jsonl" > "$RUN_DIR/logs/last_message.md"

# トークン usage（最後のturn.completedを採用）
jq -c 'select(.type=="turn.completed") | .usage' "$RUN_DIR/logs/events.jsonl" | tail -n 1 > "$RUN_DIR/logs/usage.json"

echo "run_dir=$RUN_DIR"
echo "target_dir=$TARGET_DIR"

"$SCRIPT_DIR/summarize_run.sh" "$RUN_DIR"

# オプション: 作業ログを自動的に日本語化する
if [[ -n "${ONESHOT_AUTO_TRANSLATE_WORKLOG:-}" ]]; then
  if ! "$SCRIPT_DIR/translate_worklog_to_ja.sh" "$RUN_DIR"; then
    echo "WARN: failed to translate worklog to Japanese" >&2
  fi
fi
