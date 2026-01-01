#!/usr/bin/env bash
# shellspec

Include specs/shells/spec_helper.sh

Describe "core/run-oneshot.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when --job missing"
    When run bash core/run-oneshot.sh
    The status should be failure
    The output should include "Usage: run-oneshot.sh"
  End

  It "fails when prompt_file and prompt_text are both set"
    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_file: prompts/a.md
prompt_text: "hello"
YAML
    When run env ONESHOT_AGENT_ROOT="$TMP_DIR/agent" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run-oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "Specify only one of prompt_file or prompt_text"
  End

  It "renders prompt with input replacement"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$AGENT/core/oneshot-exec.sh"
    chmod +x "$AGENT/core/oneshot-exec.sh"
    INPUT_PATH="$AGENT/input.txt"
    printf 'world' > "$INPUT_PATH"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: |
  Hello __INPUT_FOO__
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run-oneshot.sh --job "$JOB" --input foo=input.txt --render-only
    The status should be success
    The output should include "run_oneshot_log="
    LOG_PATH="$(ls "$TMP_DIR/test-worklogs/test"/*/logs/run-oneshot.log 2>/dev/null | head -n 1)"
    The path "$LOG_PATH" should exist
    The contents of file "$LOG_PATH" should include "Hello world"
  End

  It "runs worktree and pr_yml flow"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/worklogs"

    # mock oneshot-exec.sh
    cat <<'MOCK' > "$AGENT/core/oneshot-exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot-exec.sh"

    # mock create-worktree.sh
    cat <<'MOCK' > "$AGENT/core/create-worktree.sh"
#!/usr/bin/env bash
set -euo pipefail

WORKTREE_ROOT=""
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree-root)
      WORKTREE_ROOT="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

if [[ -z "$WORKTREE_ROOT" ]]; then
  WORKTREE_ROOT="$PWD/worklogs"
fi
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="run"
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "worktree_dir=$WORKTREE_DIR"
echo "branch=test-branch"
echo "base_branch=main"
MOCK
    chmod +x "$AGENT/core/create-worktree.sh"

    # mock generate-pr-yml.sh
    cat <<'MOCK' > "$AGENT/core/generate-pr-yml.sh"
#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="$1"
mkdir -p "$RUN_DIR"
cat <<'YAML' > "$RUN_DIR/pr.yml"
title: テストPR
body: |
  # 概要
  - テスト

  # 変更点
  - ダミー

  # 影響範囲
  - なし

  # 確認コマンド
  - 未実行
YAML

echo "generated: $RUN_DIR/pr.yml"
MOCK
    chmod +x "$AGENT/core/generate-pr-yml.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: true
pr_yml: true
target_dir: /tmp/target
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run-oneshot.sh --job "$JOB"
    The status should be success
    The output should include "worktree_dir="
    The output should include "generated:"
  End

  It "passes model and thinking to oneshot-exec"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot-exec.sh"
#!/usr/bin/env bash
set -euo pipefail

echo "model=$ONESHOT_MODEL"
echo "thinking=$ONESHOT_THINKING"
MOCK
    chmod +x "$AGENT/core/oneshot-exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
model: gpt-5.2-codex
thinking: high
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run-oneshot.sh --job "$JOB"
    The status should be success
    The output should include "model=gpt-5.2-codex"
    The output should include "thinking=high"
  End
End
