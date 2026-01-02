#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_mode.sh --mode <mode.yml> [--input <key=path>] [--render-only]

Mode spec (flat):
  name: issue-planning
  prompt_text: "..."
  skills:
    - some-skill
    # or file paths: skills/optional/some-skill.md
  model: gpt-5.2-codex
  thinking: medium

Notes:
- prompt_text は必須。
- inputs は __INPUT_<KEY>__ に置換される（KEYは大文字化）。
- --input のパスは ONESHOT_AGENT_ROOT からの相対パスとして解決される。
USAGE
}

MODE_SPEC=""
RENDER_ONLY=0
INPUT_OVERRIDES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE_SPEC="$2"
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

if [[ -z "$MODE_SPEC" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$MODE_SPEC" ]]; then
  echo "Mode spec not found: $MODE_SPEC" >&2
  exit 1
fi

: "${ONESHOT_AGENT_ROOT:?ONESHOT_AGENT_ROOT is not set}"
AGENT_ROOT="$ONESHOT_AGENT_ROOT"
MODE_SPEC_DIR="$(cd "$(dirname "$MODE_SPEC")" && pwd)"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

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

NAME=""
PROMPT_TEXT=""
MODEL=""
THINKING=""
SKILLS=()
SKILL_FILES=()
INPUT_KEYS=()
INPUT_VALS=()
IN_SKILLS_BLOCK=0
IN_PROMPT_TEXT_BLOCK=0
PROMPT_TEXT_INDENT=""

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  raw_line="$line"
  line="$(trim "$line")"
  if [[ $IN_PROMPT_TEXT_BLOCK -eq 1 ]]; then
    if [[ -z "$raw_line" ]]; then
      PROMPT_TEXT+=$'\n'
      continue
    fi
    if [[ -n "$PROMPT_TEXT_INDENT" && "${raw_line}" != ${PROMPT_TEXT_INDENT}* ]]; then
      IN_PROMPT_TEXT_BLOCK=0
    else
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
      prompt_text)
        if [[ "$val" == "|" ]]; then
          IN_PROMPT_TEXT_BLOCK=1
          PROMPT_TEXT_INDENT="  "
        else
          PROMPT_TEXT="$val"
        fi
        ;;
      model) MODEL="$val" ;;
      thinking|thinking_level) THINKING="$val" ;;
      *) : ;;
    esac
  fi
done < "$MODE_SPEC"

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "prompt_text is required in mode spec: $MODE_SPEC" >&2
  exit 1
fi

if [[ -z "$NAME" ]]; then
  base="$(basename "$MODE_SPEC")"
  NAME="${base%.yml}"
  NAME="${NAME%.yaml}"
fi

RUN_ID="${ONESHOT_RUN_ID:-}"
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(date +%Y%m%d-%H%M%S)-$RANDOM"
fi

DEFAULT_RUNS_DIR="$AGENT_ROOT/worklogs/modes/$NAME"
RUNS_DIR="${ONESHOT_RUNS_DIR:-$DEFAULT_RUNS_DIR}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/prompts" "$RUN_DIR/inputs"

RAW_PROMPT_FILE="$RUN_DIR/prompts/prompt.raw.txt"
FINAL_PROMPT_FILE="$RUN_DIR/prompts/prompt.txt"
printf '%s' "$PROMPT_TEXT" > "$RAW_PROMPT_FILE"

PROMPT_TMP="$FINAL_PROMPT_FILE"
cp "$RAW_PROMPT_FILE" "$PROMPT_TMP"

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
  resolved_path="$AGENT_ROOT/$v"
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

GLOBAL_SKILL_FILES=()
GLOBAL_SKILLS_DIR="$AGENT_ROOT/skills/global"
if [[ -z "${ONESHOT_DISABLE_GLOBAL_SKILLS:-}" && -d "$GLOBAL_SKILLS_DIR" ]]; then
  while IFS= read -r f; do
    GLOBAL_SKILL_FILES+=("$f")
  done < <(ls "$GLOBAL_SKILLS_DIR"/*.md 2>/dev/null | sort || true)
fi

OPTIONAL_SKILL_FILES=()
OPTIONAL_SKILLS_DIR="$AGENT_ROOT/skills/optional"
if [[ -d "$OPTIONAL_SKILLS_DIR" ]]; then
  if [[ ${#SKILLS[@]} -gt 0 ]]; then
    for __name in "${SKILLS[@]}"; do
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
fi

if [[ ${#SKILL_FILES[@]} -gt 0 ]]; then
  for entry in "${SKILL_FILES[@]}"; do
    if [[ "$entry" = /* ]]; then
      OPTIONAL_SKILL_FILES+=("$entry")
    elif [[ -f "$AGENT_ROOT/$entry" ]]; then
      OPTIONAL_SKILL_FILES+=("$AGENT_ROOT/$entry")
    elif [[ -f "$MODE_SPEC_DIR/$entry" ]]; then
      OPTIONAL_SKILL_FILES+=("$MODE_SPEC_DIR/$entry")
    else
      echo "Skill file not found: $entry" >&2
      exit 1
    fi
  done
fi

if [[ ${#GLOBAL_SKILL_FILES[@]} -gt 0 || ${#OPTIONAL_SKILL_FILES[@]} -gt 0 ]]; then
  SKILL_PROMPT="$RUN_DIR/prompts/prompt.with-skills.txt"
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
    cat "$PROMPT_TMP"
  } > "$SKILL_PROMPT"
  PROMPT_TMP="$SKILL_PROMPT"
fi

if [[ $RENDER_ONLY -eq 1 ]]; then
  cat "$PROMPT_TMP"
  exit 0
fi

TARGET_DIR="${ONESHOT_PROJECT_ROOT:-$PWD}"

CMD=(codex --cd "$TARGET_DIR")
if [[ -n "$MODEL" ]]; then
  CMD+=( --model "$MODEL" )
fi
if [[ -n "$THINKING" ]]; then
  CMD+=( -c "reasoning.effort=${THINKING}" )
fi

PROMPT_CONTENT="$(cat "$PROMPT_TMP")"

env \
  ONESHOT_MODE_NAME="$NAME" \
  ONESHOT_MODE_RUN_ID="$RUN_ID" \
  ONESHOT_MODE_RUN_DIR="$RUN_DIR" \
  ONESHOT_MODE_INPUTS_DIR="$RUN_DIR/inputs" \
  "${CMD[@]}" \
  "$PROMPT_CONTENT"
