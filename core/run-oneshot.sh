#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run-oneshot.sh --spec <spec.yml> [--audit-report <file>] [--render-only]

YAML spec (flat):
  name: doc-audit
  prompt_file: prompts/doc-audit.md
  prompt_text: "..."
  skills:
    - doc-audit
  target_dir: /path/to/project
  disable_global_skills: true

Notes:
- prompt_file と prompt_text はどちらか一方を指定。
- target_dir 未指定時は ONESHOT_PROJECT_ROOT -> PROJECT_ROOT -> PWD の順で使用。
- __AUDIT_REPORT__ は必要に応じて置換される。
USAGE
}

SPEC=""
AUDIT_REPORT_SRC=""
RENDER_ONLY=0
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

if [[ -z "$SPEC" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$SPEC" ]]; then
  echo "Spec not found: $SPEC" >&2
  exit 1
fi

SPEC_DIR="$(cd "$(dirname "$SPEC")" && pwd)"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

NAME=""
PROMPT_FILE=""
PROMPT_TEXT=""
TARGET_DIR=""
DISABLE_GLOBAL=""
SKILLS=()
IN_SKILLS_BLOCK=0

while IFS= read -r line || [[ -n "$line" ]]; do
  # strip comments
  line="${line%%#*}"
  line="$(trim "$line")"
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
      prompt_text) PROMPT_TEXT="$val" ;;
      target_dir) TARGET_DIR="$val" ;;
      disable_global_skills) DISABLE_GLOBAL="$val" ;;
      *) : ;;
    esac
  fi

  done < "$SPEC"

if [[ -z "$NAME" ]]; then
  base="$(basename "$SPEC")"
  NAME="${base%.*}"
fi

if [[ -n "$PROMPT_FILE" && -n "$PROMPT_TEXT" ]]; then
  echo "Specify only one of prompt_file or prompt_text" >&2
  exit 1
fi

if [[ -z "$PROMPT_FILE" && -z "$PROMPT_TEXT" ]]; then
  echo "prompt_file or prompt_text is required" >&2
  exit 1
fi

if [[ -z "$TARGET_DIR" ]]; then
  if [[ -n "${ONESHOT_PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$ONESHOT_PROJECT_ROOT"
  elif [[ -n "${PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$PROJECT_ROOT"
  else
    TARGET_DIR="$(pwd)"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
ONESHOT="$ROOT_DIR/core/oneshot-exec.sh"

if [[ ! -x "$ONESHOT" ]]; then
  echo "oneshot-exec.sh not found: $ONESHOT" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

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
    if [[ -f "$AUDIT_REPORT_SRC" ]]; then
      python3 - "$PROMPT_TMP" "$AUDIT_REPORT_SRC" <<'PY'
import sys
from pathlib import Path

prompt_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])

text = prompt_path.read_text()
report = report_path.read_text()
prompt_path.write_text(text.replace("__AUDIT_REPORT__", report))
PY
    else
      echo "audit report not found: $AUDIT_REPORT_SRC" >&2
      exit 1
    fi
  fi
  PROMPT_PATH="$PROMPT_TMP"
fi

if [[ $RENDER_ONLY -eq 1 ]]; then
  cat "$PROMPT_PATH"
  exit 0
fi

RUNS_DIR="$ROOT_DIR/worklogs/$NAME"
mkdir -p "$RUNS_DIR"

SKILLS_ARG=()
if [[ ${#SKILLS[@]} -gt 0 ]]; then
  SKILLS_ARG=( -s "$(IFS=,; echo "${SKILLS[*]}")" )
fi

DISABLE_GLOBAL_ENV=()
if [[ "$DISABLE_GLOBAL" == "true" || "$DISABLE_GLOBAL" == "1" ]]; then
  DISABLE_GLOBAL_ENV=( ONESHOT_DISABLE_GLOBAL_SKILLS=1 )
fi

if [[ ${#DISABLE_GLOBAL_ENV[@]} -gt 0 ]]; then
  OUTPUT="$(ONESHOT_RUNS_DIR="$RUNS_DIR" \
    "${DISABLE_GLOBAL_ENV[@]}" \
    "$ONESHOT" -C "$TARGET_DIR" "${SKILLS_ARG[@]}" "$PROMPT_PATH")"
else
  OUTPUT="$(ONESHOT_RUNS_DIR="$RUNS_DIR" \
    "$ONESHOT" -C "$TARGET_DIR" "${SKILLS_ARG[@]}" "$PROMPT_PATH")"
fi

echo "$OUTPUT"

RUN_DIR="$(printf '%s\n' "$OUTPUT" | awk -F= '/^run_dir=/{print $2}' | tail -n 1)"
if [[ -n "$RUN_DIR" ]]; then
  if [[ -n "$AUDIT_REPORT_SRC" && -f "$AUDIT_REPORT_SRC" ]]; then
    cp "$AUDIT_REPORT_SRC" "$RUN_DIR/audit_report.txt"
  fi
fi
