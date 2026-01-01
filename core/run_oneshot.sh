#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_oneshot.sh --job <job.yml> [--audit-report <file>] [--input <key=path>] [--render-only]

YAML job spec (flat):
  name: doc-audit
  prompt_file: prompts/doc-audit.md
  prompt_text: "..."
  skills:
    - doc-audit
    # or file paths: skills/optional/doc-audit.md
  target_dir: /path/to/project
  worktree: true
  pr: true
  pr_yml: true
  pr_draft: true
  disable_global_skills: true
  model: gpt-5.2-codex
  thinking: medium

Notes:
- prompt_file と prompt_text はどちらか一方を指定。
- target_dir 未指定時は ONESHOT_PROJECT_ROOT -> PROJECT_ROOT -> PWD の順で使用。
- inputs は __INPUT_<KEY>__ に置換される（KEYは大文字化）。
- --input のパスは ONESHOT_AGENT_ROOT からの相対パスとして解決される。
- pr_yml は worktree: true が前提（worklogs/<job>/<run_id>/worktree を参照）。
- thinking は Codex CLI の reasoning.effort に渡される。
- ONESHOT_WORKLOGS_ROOT が指定されている場合、worklogs のルートとして使われます。
USAGE
}

JOB_SPEC=""
AUDIT_REPORT_SRC=""
RENDER_ONLY=0
INPUT_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --job)
      JOB_SPEC="$2"
      shift 2
      ;;
    --audit-report)
      AUDIT_REPORT_SRC="$2"
      shift 2
      ;;
    --input)
      INPUT_OVERRIDES+=("$2")
      shift 2
      ;;
    --render-only)
      RENDER_ONLY=1
      shift 1
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

# 必須引数の検証
if [[ -z "$JOB_SPEC" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$JOB_SPEC" ]]; then
  echo "Job spec not found: $JOB_SPEC" >&2
  exit 1
fi

# job spec パス起点の解決用ディレクトリ
JOB_SPEC_DIR="$(cd "$(dirname "$JOB_SPEC")" && pwd)"

# 文字列前後の空白を削る
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# __INPUT_<KEY>__ の置換キーを管理
set_input() {
  local k="$1"
  local v="$2"
  local i
  for i in "${!INPUT_KEYS[@]}"; do
    if [[ "${INPUT_KEYS[$i]}" == "$k" ]]; then
      INPUT_VALS[$i]="$v"
      return
    fi
  done
  INPUT_KEYS+=("$k")
  INPUT_VALS+=("$v")
}

# job spec から読み取る設定値
NAME=""
PROMPT_FILE=""
PROMPT_TEXT=""
TARGET_DIR=""
USE_WORKTREE=""
PR_ENABLED=""
PR_YML=""
PR_DRAFT=""
DISABLE_GLOBAL=""
MODEL=""
THINKING=""
SKILLS=()
SKILL_FILES=()
INPUT_KEYS=()
INPUT_VALS=()
IN_SKILLS_BLOCK=0
IN_PROMPT_TEXT_BLOCK=0
PROMPT_TEXT_INDENT=""

# job spec を最小限パース（フラット YAML）
while IFS= read -r line || [[ -n "$line" ]]; do
  # strip comments
  line="${line%%#*}"
  # keep raw for block parsing
  raw_line="$line"
  line="$(trim "$line")"
  if [[ $IN_PROMPT_TEXT_BLOCK -eq 1 ]]; then
    # end block if indentation is shorter than the block indent
    if [[ -z "$raw_line" ]]; then
      PROMPT_TEXT+=$'\n'
      continue
    fi
    if [[ -n "$PROMPT_TEXT_INDENT" && "${raw_line}" != ${PROMPT_TEXT_INDENT}* ]]; then
      IN_PROMPT_TEXT_BLOCK=0
    else
      # strip the block indent prefix
      PROMPT_TEXT+="${raw_line#${PROMPT_TEXT_INDENT}}"
      PROMPT_TEXT+=$'\n'
      continue
    fi
  fi
  [[ -z "$line" ]] && continue

  if [[ "$line" == skills:* ]]; then
    IN_SKILLS_BLOCK=1
    continue
  fi
  if [[ $IN_SKILLS_BLOCK -eq 1 ]]; then
    if [[ "$line" == -* ]]; then
      skill="$(trim "${line#-}")"
      if [[ -n "$skill" ]]; then
        if [[ "$skill" == *"/"* || "$skill" == *.md ]]; then
          SKILL_FILES+=("$skill")
        else
          SKILLS+=("$skill")
        fi
      fi
      continue
    else
      IN_SKILLS_BLOCK=0
    fi
  fi
  if [[ "$line" =~ ^[a-zA-Z0-9_]+: ]]; then
    key="${line%%:*}"
    val="$(trim "${line#*:}")"
    case "$key" in
      name) NAME="$val" ;;
      prompt_file) PROMPT_FILE="$val" ;;
      prompt_text)
        if [[ "$val" == "|" ]]; then
          IN_PROMPT_TEXT_BLOCK=1
          # detect indent from next line by using leading spaces of raw_line after "prompt_text:"
          PROMPT_TEXT_INDENT="  "
        else
          PROMPT_TEXT="$val"
        fi
        ;;
      target_dir) TARGET_DIR="$val" ;;
      worktree) USE_WORKTREE="$val" ;;
      pr) PR_ENABLED="$val" ;;
      pr_yml) PR_YML="$val" ;;
      pr_draft) PR_DRAFT="$val" ;;
      disable_global_skills) DISABLE_GLOBAL="$val" ;;
      model) MODEL="$val" ;;
      thinking|thinking_level) THINKING="$val" ;;
      *) : ;;
    esac
  fi

  done < "$JOB_SPEC"

# name が無い場合はファイル名から推定
if [[ -z "$NAME" ]]; then
  base="$(basename "$JOB_SPEC")"
  NAME="${base%.*}"
fi

# prompt 指定の整合性チェック
if [[ -n "$PROMPT_FILE" && -n "$PROMPT_TEXT" ]]; then
  echo "Specify only one of prompt_file or prompt_text" >&2
  exit 1
fi

if [[ -z "$PROMPT_FILE" && -z "$PROMPT_TEXT" ]]; then
  echo "prompt_file or prompt_text is required" >&2
  exit 1
fi

# ターゲットディレクトリの決定
if [[ -z "$TARGET_DIR" ]]; then
  if [[ -n "${ONESHOT_PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$ONESHOT_PROJECT_ROOT"
  elif [[ -n "${PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$PROJECT_ROOT"
  else
    TARGET_DIR="$(pwd)"
  fi
fi

# worktree デフォルト（true）
if [[ -z "$USE_WORKTREE" ]]; then
  USE_WORKTREE="true"
fi

# PR有効時は pr-draft スキルを自動追加
if [[ "$PR_ENABLED" == "true" || "$PR_ENABLED" == "1" ]]; then
  already=0
  for s in "${SKILLS[@]:-}"; do
    if [[ "$s" == "pr-draft" ]]; then
      already=1
      break
    fi
  done
  if [[ $already -eq 0 ]]; then
    for f in "${SKILL_FILES[@]:-}"; do
      base="$(basename "$f")"
      dir_base="$(basename "$(dirname "$f")")"
      if [[ "$base" == "pr-draft.md" || ( "$base" == "SKILL.md" && "$dir_base" == "pr-draft" ) ]]; then
        already=1
        break
      fi
    done
  fi
  if [[ $already -eq 0 ]]; then
    SKILLS+=("pr-draft")
  fi
fi

# スクリプト/ルートの解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${ONESHOT_AGENT_ROOT:?ONESHOT_AGENT_ROOT is not set}"
AGENT_ROOT="$ONESHOT_AGENT_ROOT"
ROOT_DIR="$AGENT_ROOT"
ONESHOT="$AGENT_ROOT/core/oneshot_exec.sh"

if [[ ! -x "$ONESHOT" ]]; then
  echo "oneshot_exec.sh not found: $ONESHOT" >&2
  exit 1
fi

# run_id とログ先を確定（早めにログを開始）
RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
WORKLOGS_ROOT="${ONESHOT_WORKLOGS_ROOT:-$AGENT_ROOT/worklogs}"
RUNS_DIR="$WORKLOGS_ROOT/$NAME"
mkdir -p "$RUNS_DIR"
RUN_DIR_PREP="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR_PREP/logs"
RUN_RUNNING_FILE="$RUN_DIR_PREP/.running"
{
  echo "pid=$$"
  echo "started_at=$(date +%Y-%m-%dT%H:%M:%S%z)"
} > "$RUN_RUNNING_FILE"
RUN_ONESHOT_LOG="$RUN_DIR_PREP/logs/run-oneshot.log"
{
  echo "run_id=$RUN_ID"
  echo "job_spec=$JOB_SPEC"
  echo "name=$NAME"
  echo "timestamp=$(date +%Y-%m-%dT%H:%M:%S%z)"
} >> "$RUN_ONESHOT_LOG"
exec 3>&1 4>&2
echo "run_oneshot_log=$RUN_ONESHOT_LOG" >&3
exec >>"$RUN_ONESHOT_LOG" 2>&1
trap 'echo "ERROR line=$LINENO cmd=$BASH_COMMAND" >&2' ERR

# 主要な結果を標準出力にも出すためのヘルパー
emit() {
  printf '%s\n' "$*" | tee -a "$RUN_ONESHOT_LOG" >&3
}

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -f "$RUN_RUNNING_FILE"
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# 旧runをアーカイブ（実行中は除外）
archive_old_runs() {
  local runs_dir="$1"
  local current_dir="$2"
  local archive_dir="$runs_dir/archive"
  local d
  local base
  local dest
  local ts
  mkdir -p "$archive_dir"
  shopt -s nullglob
  for d in "$runs_dir"/*; do
    [[ "$d" == "$archive_dir" ]] && continue
    [[ "$d" == "$current_dir" ]] && continue
    [[ -d "$d" ]] || continue
    [[ -f "$d/.running" ]] && continue
    base="$(basename "$d")"
    dest="$archive_dir/$base"
    if [[ -e "$dest" ]]; then
      ts="$(date +%Y%m%d-%H%M%S)"
      dest="$archive_dir/$base.$ts"
    fi
    if [[ -e "$dest" ]]; then
      dest="$archive_dir/$base.$RANDOM"
    fi
    mv "$d" "$dest"
    emit "archived_run=$dest"
  done
  shopt -u nullglob
}
archive_old_runs "$RUNS_DIR" "$RUN_DIR_PREP"

# prompt ファイル/テキストの解決
PROMPT_PATH=""
if [[ -n "$PROMPT_FILE" ]]; then
  if [[ "$PROMPT_FILE" = /* ]]; then
    PROMPT_PATH="$PROMPT_FILE"
  else
    PROMPT_PATH="$AGENT_ROOT/$PROMPT_FILE"
  fi
else
  PROMPT_PATH="$TMP_DIR/prompt.txt"
  printf '%s' "$PROMPT_TEXT" > "$PROMPT_PATH"
fi

if [[ -f "$PROMPT_PATH" ]]; then
  PROMPT_TMP="$TMP_DIR/prompt.rendered.txt"
  cp "$PROMPT_PATH" "$PROMPT_TMP"
  if [[ -n "$AUDIT_REPORT_SRC" ]]; then
    set_input "audit_report" "$AUDIT_REPORT_SRC"
  fi
  if [[ ${#INPUT_OVERRIDES[@]} -gt 0 ]]; then
    for override in "${INPUT_OVERRIDES[@]}"; do
      k="${override%%=*}"
      v="${override#*=}"
      if [[ -z "$k" || "$k" == "$override" ]]; then
        echo "Invalid --input (expected key=path): $override" >&2
        exit 1
      fi
      set_input "$k" "$v"
    done
  fi
  for i in "${!INPUT_KEYS[@]}"; do
    k="${INPUT_KEYS[$i]}"
    v="${INPUT_VALS[$i]}"
    resolved_path=""
    if [[ -z "${ONESHOT_AGENT_ROOT:-}" ]]; then
      echo "ONESHOT_AGENT_ROOT is required for --input path resolution" >&2
      exit 1
    fi
    resolved_path="$ONESHOT_AGENT_ROOT/$v"
    if [[ ! -f "$resolved_path" ]]; then
      if [[ -f "$v" ]]; then
        resolved_path="$v"
      else
        echo "Input file not found: key=$k, value=$v, resolved=$resolved_path" >&2
        exit 1
      fi
    fi
    key_upper="$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"
    placeholder="__INPUT_${key_upper}__"
    python3 - "$PROMPT_TMP" "$resolved_path" "$placeholder" <<'PY'
import sys
from pathlib import Path

prompt_path = Path(sys.argv[1])
content_path = Path(sys.argv[2])
placeholder = sys.argv[3]

text = prompt_path.read_text()
content = content_path.read_text()
prompt_path.write_text(text.replace(placeholder, content))
PY
  done
  PROMPT_PATH="$PROMPT_TMP"
fi

# job spec で指定された skill file をプロンプト先頭に展開
if [[ ${#SKILL_FILES[@]} -gt 0 ]]; then
  SKILL_PROMPT="$TMP_DIR/prompt.with-skill-files.txt"
  {
    echo "# Job Skill Files"
    for entry in "${SKILL_FILES[@]}"; do
      resolved=""
      if [[ "$entry" = /* ]]; then
        resolved="$entry"
      elif [[ -n "${AGENT_ROOT:-}" && -f "$AGENT_ROOT/$entry" ]]; then
        resolved="$AGENT_ROOT/$entry"
      elif [[ -f "$JOB_SPEC_DIR/$entry" ]]; then
        resolved="$JOB_SPEC_DIR/$entry"
      fi
      if [[ -z "$resolved" || ! -f "$resolved" ]]; then
        echo "Skill file not found: $entry" >&2
        exit 1
      fi
      display="$resolved"
      if [[ -n "${AGENT_ROOT:-}" && "$resolved" == "$AGENT_ROOT/"* ]]; then
        display="${resolved#"$AGENT_ROOT/"}"
      fi
      echo ""
      echo "## skill_file: $display"
      echo ""
      cat "$resolved"
    done
    echo ""
    cat "$PROMPT_PATH"
  } > "$SKILL_PROMPT"
  PROMPT_PATH="$SKILL_PROMPT"
fi

# レンダリングのみ（置換結果の出力）
if [[ $RENDER_ONLY -eq 1 ]]; then
  cat "$PROMPT_PATH"
  exit 0
fi

# worktree 作成対象のリポジトリ
REPO_DIR="$TARGET_DIR"

WORKTREE_DIR=""
WORKTREE_BRANCH=""
WORKTREE_BASE=""
# worktree を作成してターゲットを差し替え
if [[ "$USE_WORKTREE" == "true" || "$USE_WORKTREE" == "1" ]]; then
  WORKTREE_SCRIPT="$ROOT_DIR/core/create_worktree.sh"
  if [[ ! -x "$WORKTREE_SCRIPT" ]]; then
    echo "create_worktree.sh not found: $WORKTREE_SCRIPT" >&2
    exit 1
  fi

  WORKTREE_OUTPUT="$("$WORKTREE_SCRIPT" \
    --repo "$TARGET_DIR" \
    --run-id "$RUN_ID" \
    --job-name "$NAME" \
    --worktree-root "$RUNS_DIR")"
  emit "$WORKTREE_OUTPUT"

  WORKTREE_DIR="$(printf '%s\n' "$WORKTREE_OUTPUT" | awk -F= '/^worktree_dir=/{print $2}' | tail -n 1)"
  WORKTREE_BRANCH="$(printf '%s\n' "$WORKTREE_OUTPUT" | awk -F= '/^branch=/{print $2}' | tail -n 1)"
  WORKTREE_BASE="$(printf '%s\n' "$WORKTREE_OUTPUT" | awk -F= '/^base_branch=/{print $2}' | tail -n 1)"
  if [[ -z "$WORKTREE_DIR" ]]; then
    echo "Failed to create worktree" >&2
    exit 1
  fi
  TARGET_DIR="$WORKTREE_DIR"
fi

# optional skills の引数生成
SKILLS_ARG=()
if [[ ${#SKILLS[@]} -gt 0 ]]; then
  SKILLS_ARG=( -s "$(IFS=,; echo "${SKILLS[*]}")" )
fi

# oneshot 実行コマンドを配列で組み立て
ONESHOT_CMD=( "$ONESHOT" -C "$TARGET_DIR" )
if [[ ${#SKILLS_ARG[@]} -gt 0 ]]; then
  ONESHOT_CMD+=( "${SKILLS_ARG[@]}" )
fi
ONESHOT_CMD+=( "$PROMPT_PATH" )

# グローバル skills 無効化フラグ
DISABLE_GLOBAL_ENV=()
if [[ "$DISABLE_GLOBAL" == "true" || "$DISABLE_GLOBAL" == "1" ]]; then
  DISABLE_GLOBAL_ENV=( ONESHOT_DISABLE_GLOBAL_SKILLS=1 )
fi

# oneshot 本体実行（失敗時の出力をログへ）
EXTRA_ENV=()
if [[ ${#DISABLE_GLOBAL_ENV[@]} -gt 0 ]]; then
  EXTRA_ENV+=( "${DISABLE_GLOBAL_ENV[@]}" )
fi
if [[ -n "$MODEL" ]]; then
  EXTRA_ENV+=( ONESHOT_MODEL="$MODEL" )
fi
if [[ -n "$THINKING" ]]; then
  EXTRA_ENV+=( ONESHOT_THINKING="$THINKING" )
fi
BASE_ENV=(
  ONESHOT_RUNS_DIR="$RUNS_DIR"
  ONESHOT_RUN_ID="$RUN_ID"
  ONESHOT_ARCHIVE_HANDLED=1
)

CMD_ENV=( "${BASE_ENV[@]}" )
if [[ ${#EXTRA_ENV[@]} -gt 0 ]]; then
  CMD_ENV+=( "${EXTRA_ENV[@]}" )
fi
set +e
OUTPUT="$(env "${CMD_ENV[@]}" "${ONESHOT_CMD[@]}")"
ONESHOT_STATUS=$?
set -e

emit "$OUTPUT"
if [[ ${ONESHOT_STATUS:-0} -ne 0 ]]; then
  emit "oneshot_exit_code=$ONESHOT_STATUS"
  exit "$ONESHOT_STATUS"
fi
# run_oneshot の補助出力
if [[ -n "$WORKTREE_DIR" ]]; then
  emit "worktree_dir=$WORKTREE_DIR"
  if [[ -n "$WORKTREE_BRANCH" ]]; then
    emit "worktree_branch=$WORKTREE_BRANCH"
  fi
fi

# inputs のメタ保存
RUN_DIR="$(printf '%s\n' "$OUTPUT" | awk -F= '/^run_dir=/{print $2}' | tail -n 1)"
if [[ -n "$RUN_DIR" ]]; then
  for i in "${!INPUT_KEYS[@]}"; do
    k="${INPUT_KEYS[$i]}"
    v="${INPUT_VALS[$i]}"
    printf '%s=%s\n' "$k" "$v" >> "$RUN_DIR/inputs/inputs.txt"
  done
fi

# PR下書きYAML生成（有効時のみ）
if [[ "$PR_YML" == "true" || "$PR_YML" == "1" ]]; then
  if [[ -z "$RUN_DIR" ]]; then
    echo "run_dir not found; cannot generate pr.yml" >&2
    exit 1
  fi
  if [[ -z "$WORKTREE_DIR" ]]; then
    echo "pr_yml requires worktree: true" >&2
    exit 1
  fi
  PR_YML_SCRIPT="$ROOT_DIR/core/generate_pr_yml.sh"
  if [[ ! -x "$PR_YML_SCRIPT" ]]; then
    echo "generate_pr_yml.sh not found: $PR_YML_SCRIPT" >&2
    exit 1
  fi
  PR_YML_OUTPUT="$("$PR_YML_SCRIPT" "$RUN_DIR")"
  emit "$PR_YML_OUTPUT"
fi

# PR作成（有効時のみ）
if [[ "$PR_ENABLED" == "true" || "$PR_ENABLED" == "1" ]]; then
  if [[ -z "$RUN_DIR" ]]; then
    echo "run_dir not found; cannot create PR" >&2
    exit 1
  fi
  if [[ -z "$WORKTREE_DIR" ]]; then
    echo "pr requires worktree: true" >&2
    exit 1
  fi
  PR_YML_PATH="$RUN_DIR/pr.yml"
  if [[ ! -f "$PR_YML_PATH" ]]; then
    PR_YML_SCRIPT="$ROOT_DIR/core/generate_pr_yml.sh"
    if [[ ! -x "$PR_YML_SCRIPT" ]]; then
      echo "generate_pr_yml.sh not found: $PR_YML_SCRIPT" >&2
      exit 1
    fi
    PR_YML_OUTPUT="$("$PR_YML_SCRIPT" "$RUN_DIR")"
    emit "$PR_YML_OUTPUT"
  fi

  PR_SCRIPT="$ROOT_DIR/core/create_pr.sh"
  if [[ ! -x "$PR_SCRIPT" ]]; then
    echo "create_pr.sh not found: $PR_SCRIPT" >&2
    exit 1
  fi

  PR_ARGS=(--repo "$REPO_DIR" --worktree "$TARGET_DIR" --pr-yml "$PR_YML_PATH")
  if [[ -n "$WORKTREE_BRANCH" ]]; then
    PR_ARGS+=(--branch "$WORKTREE_BRANCH")
  fi
  if [[ -n "$WORKTREE_BASE" ]]; then
    PR_ARGS+=(--base "$WORKTREE_BASE")
  fi
  if [[ "$PR_DRAFT" == "true" || "$PR_DRAFT" == "1" ]]; then
    PR_ARGS+=(--draft)
  fi
  PR_ARGS+=(--commit-message "${NAME}: update (${RUN_ID})")

  PR_OUTPUT="$("$PR_SCRIPT" "${PR_ARGS[@]}")"
  emit "$PR_OUTPUT"
fi
