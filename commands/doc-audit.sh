#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: doc-audit.sh [-C <target_dir>] [--scope <glob>] [--exclude <glob>]

  -C DIR       対象リポジトリ（省略時はカレント）
  --scope GLOB 対象範囲の追加（複数指定可）
  --exclude G  除外範囲の追加（複数指定可）
USAGE
}

have() { command -v "$1" >/dev/null 2>&1; }

ORIG_ARGS=("$@");
TARGET_DIR=""
ROOT_ENV_NAME=""
SCOPE_GLOBS=()
EXCLUDE_GLOBS=(".git/**" "node_modules/**" "playground/**" "worklogs/**")

while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      TARGET_DIR="$2"
      shift 2
      ;;
    --scope)
      SCOPE_GLOBS+=("$2")
      shift 2
      ;;
    --exclude)
      EXCLUDE_GLOBS+=("$2")
      shift 2
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

if [[ -z "$TARGET_DIR" ]]; then
  if [[ -n "${ONESHOT_PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$ONESHOT_PROJECT_ROOT"
    ROOT_ENV_NAME="ONESHOT_PROJECT_ROOT"
  elif [[ -n "${PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$PROJECT_ROOT"
    ROOT_ENV_NAME="PROJECT_ROOT"
  else
    TARGET_DIR="$(pwd)"
  fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target dir not found: $TARGET_DIR" >&2
  exit 1
fi

if [[ ${#SCOPE_GLOBS[@]} -eq 0 ]]; then
  SCOPE_GLOBS=("*.md" "README*" "docs/**")
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

DOC_INDEX="$TMP_DIR/doc_index.txt"
PROMPT_FILE="$TMP_DIR/prompt.txt"

# ファイル一覧を収集（相対パス）
if have rg; then
  RG_ARGS=(--files)
  for g in "${SCOPE_GLOBS[@]}"; do
    RG_ARGS+=( -g "$g" )
  done
  for g in "${EXCLUDE_GLOBS[@]}"; do
    RG_ARGS+=( -g "!$g" )
  done

  pushd "$TARGET_DIR" >/dev/null
  rg "${RG_ARGS[@]}" > "$DOC_INDEX" || true
  popd >/dev/null
else
  pushd "$TARGET_DIR" >/dev/null
  find . -type f \( -name "*.md" -o -name "README*" -o -path "./docs/*" \) \
    -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./playground/*" -not -path "./worklogs/*" \
    | sed 's|^\./||' \
    | sort > "$DOC_INDEX"
  popd >/dev/null
fi

if [[ ! -s "$DOC_INDEX" ]]; then
  echo "No document files found in: $TARGET_DIR" >&2
  exit 1
fi

# 実行コマンド（再現用）
CMD_TARGET_DISPLAY="$TARGET_DIR"
if [[ -n "$ROOT_ENV_NAME" ]]; then
  CMD_TARGET_DISPLAY="\${$ROOT_ENV_NAME}"
fi
CMD_STR="bash $(printf '%q ' "$0" "${ORIG_ARGS[@]}")"
CMD_STR="${CMD_STR//${TARGET_DIR}/$CMD_TARGET_DISPLAY}"
CMD_STR="${CMD_STR% }"

{
  cat <<'PROMPT'
ドキュメント監査を実施してください。以下の対象ファイル一覧に基づき、不整合の洗い出しだけを行い、修正はしないでください。

必須出力: Markdown レポート。
必須セクション:
1) 概要
2) 実行コマンド（実際に叩いたコマンド全文）
3) 調査プロセス（手順の箇条書き）
4) 不整合一覧（重大度/概要/根拠ファイル）
5) 根拠詳細（該当ファイルの引用 or 要約）

調査プロセスには以下を含めてください:
- 対象ファイル一覧の収集
- 内容の精査
- 不整合の抽出
- 重要度付け

実行コマンド:
PROMPT
  printf '%s\n' "$CMD_STR"
  cat <<'PROMPT'

注意:
- 実行コマンド欄には上記1行のみをそのまま記載すること。
- 実行していないコマンドを列挙・推測しないこと。

対象ファイル一覧:
```
PROMPT
  cat "$DOC_INDEX"
  cat <<'PROMPT'
```
PROMPT
} > "$PROMPT_FILE"

# optional skill を付与して oneshot 実行
OUTPUT="$($ONESHOT -C "$TARGET_DIR" -s doc-audit "$PROMPT_FILE")"

# run_dir 抽出して doc_index を保存
RUN_DIR="$(printf '%s\n' "$OUTPUT" | awk -F= '/^run_dir=/{print $2}' | tail -n 1)"
if [[ -n "$RUN_DIR" ]]; then
  cp "$DOC_INDEX" "$RUN_DIR/doc_index.txt"
fi

printf '%s\n' "$OUTPUT"
