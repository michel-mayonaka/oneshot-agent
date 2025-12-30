#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run-oneshot.sh --spec <spec.yml> [--audit-report <file>] [--input <key=path>] [--render-only]

YAML spec (flat):
  name: doc-audit
  prompt_file: prompts/doc-audit.md
  prompt_text: "..."
  skills:
    - doc-audit
  target_dir: /path/to/project
  worktree: true
  pr: true
  pr_title: "..."
  pr_body_file: /path/to/body.md
  pr_draft: true
  disable_global_skills: true

Notes:
- prompt_file と prompt_text はどちらか一方を指定。
- target_dir 未指定時は ONESHOT_PROJECT_ROOT -> PROJECT_ROOT -> PWD の順で使用。
- inputs は __INPUT_<KEY>__ に置換される（KEYは大文字化）。
- --input のパスは ONESHOT_AGENT_ROOT からの相対パスとして解決される。
USAGE
}

SPEC=""
AUDIT_REPORT_SRC=""
RENDER_ONLY=0
INPUT_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)
      SPEC="$2"
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
if [[ -z "$SPEC" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$SPEC" ]]; then
  echo "Spec not found: $SPEC" >&2
  exit 1
fi

# spec パス起点の解決用ディレクトリ
SPEC_DIR="$(cd "$(dirname "$SPEC")" && pwd)"

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

# spec から読み取る設定値
NAME=""
PROMPT_FILE=""
PROMPT_TEXT=""
TARGET_DIR=""
USE_WORKTREE=""
PR_ENABLED=""
PR_TITLE=""
PR_BODY_FILE=""
PR_DRAFT=""
DISABLE_GLOBAL=""
SKILLS=()
INPUT_KEYS=()
INPUT_VALS=()
IN_SKILLS_BLOCK=0
IN_PROMPT_TEXT_BLOCK=0
PROMPT_TEXT_INDENT=""

# spec を最小限パース（フラット YAML）
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
      [[ -n "$skill" ]] && SKILLS+=("$skill")
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
      pr_title) PR_TITLE="$val" ;;
      pr_body_file) PR_BODY_FILE="$val" ;;
      pr_draft) PR_DRAFT="$val" ;;
      disable_global_skills) DISABLE_GLOBAL="$val" ;;
      *) : ;;
    esac
  fi

  done < "$SPEC"

# name が無い場合はファイル名から推定
if [[ -z "$NAME" ]]; then
  base="$(basename "$SPEC")"
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
    SKILLS+=("pr-draft")
  fi
fi

# スクリプト/ルートの解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ONESHOT="$ROOT_DIR/core/oneshot-exec.sh"

if [[ ! -x "$ONESHOT" ]]; then
  echo "oneshot-exec.sh not found: $ONESHOT" >&2
  exit 1
fi

# run_id とログ先を確定（早めにログを開始）
RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
RUNS_DIR="$ROOT_DIR/worklogs/$NAME"
mkdir -p "$RUNS_DIR"
RUN_DIR_PREP="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR_PREP/logs"
RUN_ONESHOT_LOG="$RUN_DIR_PREP/logs/run-oneshot.log"
{
  echo "run_id=$RUN_ID"
  echo "spec=$SPEC"
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
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# prompt ファイル/テキストの解決
PROMPT_PATH=""
if [[ -n "$PROMPT_FILE" ]]; then
  if [[ "$PROMPT_FILE" = /* ]]; then
    PROMPT_PATH="$PROMPT_FILE"
  else
    PROMPT_PATH="$ROOT_DIR/$PROMPT_FILE"
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
  WORKTREE_SCRIPT="$ROOT_DIR/core/create-worktree.sh"
  if [[ ! -x "$WORKTREE_SCRIPT" ]]; then
    echo "create-worktree.sh not found: $WORKTREE_SCRIPT" >&2
    exit 1
  fi

  WORKTREE_OUTPUT="$("$WORKTREE_SCRIPT" \
    --repo "$TARGET_DIR" \
    --run-id "$RUN_ID" \
    --spec-name "$NAME" \
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
if [[ ${#DISABLE_GLOBAL_ENV[@]} -gt 0 ]]; then
  set +e
  OUTPUT="$(ONESHOT_RUNS_DIR="$RUNS_DIR" \
    ONESHOT_RUN_ID="$RUN_ID" \
    "${DISABLE_GLOBAL_ENV[@]}" \
    "${ONESHOT_CMD[@]}")"
  ONESHOT_STATUS=$?
  set -e
else
  set +e
  OUTPUT="$(ONESHOT_RUNS_DIR="$RUNS_DIR" \
    ONESHOT_RUN_ID="$RUN_ID" \
    "${ONESHOT_CMD[@]}")"
  ONESHOT_STATUS=$?
  set -e
fi

emit "$OUTPUT"
if [[ ${ONESHOT_STATUS:-0} -ne 0 ]]; then
  emit "oneshot_exit_code=$ONESHOT_STATUS"
  exit "$ONESHOT_STATUS"
fi
# run-oneshot の補助出力
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

# PR作成（有効時のみ）
if [[ "$PR_ENABLED" == "true" || "$PR_ENABLED" == "1" ]]; then
  PR_SCRIPT="$ROOT_DIR/core/create-pr.sh"
  if [[ ! -x "$PR_SCRIPT" ]]; then
    echo "create-pr.sh not found: $PR_SCRIPT" >&2
    exit 1
  fi

  PR_ARGS=(--repo "$REPO_DIR" --worktree "$TARGET_DIR")
  if [[ -n "$WORKTREE_BRANCH" ]]; then
    PR_ARGS+=(--branch "$WORKTREE_BRANCH")
  fi
  if [[ -n "$WORKTREE_BASE" ]]; then
    PR_ARGS+=(--base "$WORKTREE_BASE")
  fi
  if [[ -n "$PR_TITLE" ]]; then
    PR_ARGS+=(--title "$PR_TITLE")
  fi
  if [[ -n "$PR_BODY_FILE" ]]; then
    if [[ "$PR_BODY_FILE" != /* ]]; then
      PR_BODY_FILE="$ROOT_DIR/$PR_BODY_FILE"
    fi
    PR_ARGS+=(--body-file "$PR_BODY_FILE")
  elif [[ -n "$RUN_DIR" && -f "$RUN_DIR/report.md" ]]; then
    PR_ARGS+=(--report "$RUN_DIR/report.md")
  fi
  if [[ "$PR_DRAFT" == "true" || "$PR_DRAFT" == "1" ]]; then
    PR_ARGS+=(--draft)
  fi
  PR_ARGS+=(--commit-message "${NAME}: update (${RUN_ID})")

  PR_OUTPUT="$("$PR_SCRIPT" "${PR_ARGS[@]}")"
  emit "$PR_OUTPUT"
fi
