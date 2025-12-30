#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: doc-fix.sh --report <summary_report.md> [-C <target_dir>]

  --report FILE  Step1のsummary_report.md
  -C DIR         対象リポジトリ（省略時はreport配下のtarget_dir.txtを参照）
USAGE
}

REPORT=""
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      REPORT="$2"
      shift 2
      ;;
    -C)
      TARGET_DIR="$2"
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

if [[ -z "$REPORT" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$REPORT" ]]; then
  echo "Report not found: $REPORT" >&2
  exit 1
fi

REPORT_DIR="$(cd "$(dirname "$REPORT")" && pwd)"

if [[ -z "$TARGET_DIR" ]]; then
  if [[ -n "${ONESHOT_PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$ONESHOT_PROJECT_ROOT"
  elif [[ -n "${PROJECT_ROOT:-}" ]]; then
    TARGET_DIR="$PROJECT_ROOT"
  elif [[ -f "$REPORT_DIR/target_dir.txt" ]]; then
    TARGET_DIR="$(cat "$REPORT_DIR/target_dir.txt")"
  else
    TARGET_DIR="$(pwd)"
  fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target dir not found: $TARGET_DIR" >&2
  exit 1
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

PROMPT_FILE="$TMP_DIR/prompt.txt"

cat > "$PROMPT_FILE" <<PROMPT
以下のドキュメント監査レポートに基づき、不整合を修正してください。

要件:
- 可能な限り具体的に修正し、曖昧なものは「要確認」として残す。
- 変更対象はドキュメントのみ（コードの振る舞い変更は行わない）。
- 不整合の根拠が薄い場合は修正を保留し、理由を明記する。
- 最後にPR草案（タイトル/概要/変更点/確認コマンド）をまとめる。
- worklogs/ や playground/ には変更を加えない。

監査レポート:
```
$(cat "$REPORT")
```
PROMPT

"$ONESHOT" -C "$TARGET_DIR" "$PROMPT_FILE"
