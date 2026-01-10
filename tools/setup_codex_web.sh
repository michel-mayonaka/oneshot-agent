#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash tools/setup_codex_web.sh [--print-env] [--check-only]

Codex Web 環境で oneshot-agent を動かすための事前チェックを行います。
- 非対話で実行できます
- 冪等です（何度実行しても壊れません）

Options:
  --print-env   ONESHOT_AGENT_ROOT を export するためのシェル断片のみ出力します
  --check-only  環境変数の案内を抑え、依存コマンドのチェックのみ行います
  -h, --help    ヘルプを表示します

Examples:
  bash tools/setup_codex_web.sh
  eval "$(bash tools/setup_codex_web.sh --print-env)"
USAGE
}

PRINT_ENV=0
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-env)
      PRINT_ENV=1
      shift
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

detect_repo_root() {
  local root=""

  if command -v git >/dev/null 2>&1; then
    if root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
      printf '%s' "$root"
      return 0
    fi
  fi

  local dir="$SCRIPT_DIR"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -d "$dir/core" && -f "$dir/core/run_oneshot.sh" && -f "$dir/AGENTS.md" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

REPO_ROOT="$(detect_repo_root || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: failed to detect repository root from: $SCRIPT_DIR" >&2
  echo "Hint: run this script inside the oneshot-agent repository." >&2
  exit 1
fi

if [[ "$PRINT_ENV" -eq 1 ]]; then
  printf 'export ONESHOT_AGENT_ROOT=%q\n' "$REPO_ROOT"
  exit 0
fi

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_package_manager() {
  if have_cmd apt-get; then
    echo "apt-get"
    return 0
  fi
  if have_cmd apt; then
    echo "apt"
    return 0
  fi
  if have_cmd yum; then
    echo "yum"
    return 0
  fi
  if have_cmd dnf; then
    echo "dnf"
    return 0
  fi
  if have_cmd apk; then
    echo "apk"
    return 0
  fi
  if have_cmd pacman; then
    echo "pacman"
    return 0
  fi
  if have_cmd brew; then
    echo "brew"
    return 0
  fi
  echo ""
}

print_install_hint() {
  local tool="$1"
  local pm="$2"

  case "$pm" in
    apt-get)
      case "$tool" in
        jq|gh|git)
          echo "  - Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y $tool"
          ;;
      esac
      ;;
    apt)
      case "$tool" in
        jq|gh|git)
          echo "  - Ubuntu/Debian: sudo apt update && sudo apt install -y $tool"
          ;;
      esac
      ;;
    yum)
      case "$tool" in
        jq|git)
          echo "  - RHEL/CentOS: sudo yum install -y $tool"
          ;;
        gh)
          echo "  - RHEL/CentOS: GitHub CLI の公式手順でリポジトリ追加後に sudo yum install -y gh"
          ;;
      esac
      ;;
    dnf)
      case "$tool" in
        jq|git)
          echo "  - Fedora/RHEL: sudo dnf install -y $tool"
          ;;
        gh)
          echo "  - Fedora/RHEL: GitHub CLI の公式手順でリポジトリ追加後に sudo dnf install -y gh"
          ;;
      esac
      ;;
    apk)
      case "$tool" in
        jq|git|gh)
          echo "  - Alpine: sudo apk add $tool"
          ;;
      esac
      ;;
    pacman)
      case "$tool" in
        jq|git|gh)
          echo "  - Arch: sudo pacman -S --noconfirm $tool"
          ;;
      esac
      ;;
    brew)
      case "$tool" in
        jq|git|gh)
          echo "  - Homebrew: brew install $tool"
          ;;
      esac
      ;;
    *)
      echo "  - Install '$tool' so it is available on PATH."
      ;;
  esac

  if [[ "$tool" == "codex" ]]; then
    cat <<'NOTE'
  - Codex Web では通常 `codex` が事前インストールされています。
  - `codex` が見つからない場合は、Codex Web 以外の環境の可能性があります。
  - ローカル等で実行する場合は「Codex CLI のインストール手順」を参照してください（未確認: npm 経由で導入できる場合があります）。
NOTE
  fi
}

echo "== oneshot-agent Codex Web setup check =="
echo "repo_root: $REPO_ROOT"

if [[ -f /etc/os-release ]]; then
  echo "-- /etc/os-release --"
  sed -n '1,6p' /etc/os-release || true
fi

echo "-- shell --"
echo "SHELL=${SHELL-}"
echo "bash: $(bash --version | head -n 1)"

pm="$(detect_package_manager)"
if [[ -n "$pm" ]]; then
  echo "package_manager: $pm"
else
  echo "package_manager: (unknown)"
fi

missing=0
for tool in codex jq gh; do
  if have_cmd "$tool"; then
    echo "OK: $tool: $(command -v "$tool")"
  else
    echo "ERROR: missing command: $tool" >&2
    print_install_hint "$tool" "$pm" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

if [[ "$CHECK_ONLY" -eq 0 ]]; then
  if [[ -z "${ONESHOT_AGENT_ROOT-}" ]]; then
    cat <<EOF
WARN: ONESHOT_AGENT_ROOT is not set.

Next action:
  export ONESHOT_AGENT_ROOT="$REPO_ROOT"
  # or:
  eval "\$(bash tools/setup_codex_web.sh --print-env)"
EOF
  elif [[ "${ONESHOT_AGENT_ROOT}" != "$REPO_ROOT" ]]; then
    cat <<EOF
WARN: ONESHOT_AGENT_ROOT points to a different path.
  current: ${ONESHOT_AGENT_ROOT}
  expected: $REPO_ROOT

Next action:
  export ONESHOT_AGENT_ROOT="$REPO_ROOT"
EOF
  else
    echo "OK: ONESHOT_AGENT_ROOT: ${ONESHOT_AGENT_ROOT}"
  fi
fi

if have_cmd gh; then
  if gh auth status -h github.com >/dev/null 2>&1; then
    echo "OK: gh auth: github.com"
  else
    cat <<'EOF'
WARN: gh auth is not ready for github.com.
Next action (choose one):
  - Set a valid token: export GH_TOKEN=... (GitHub PAT with required scopes)
  - Or run: gh auth login
EOF
  fi
fi

echo "Done."
