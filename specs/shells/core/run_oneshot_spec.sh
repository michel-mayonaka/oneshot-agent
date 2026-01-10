#!/usr/bin/env bash
# shellspec

Include specs/shells/spec_helper.sh

Describe "core/run_oneshot.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when --job missing"
    When run bash core/run_oneshot.sh
    The status should be failure
    The output should include "Usage: run_oneshot.sh"
  End

  It "uses job filename when name is omitted"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job-no-name.yml"
    cat <<'YAML' > "$JOB"
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The path "$TMP_DIR/test-worklogs/job-no-name" should exist
  End

  It "fails when prompt_file and prompt_text are both set"
    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_file: prompts/a.md
prompt_text: "hello"
YAML
    When run env ONESHOT_AGENT_ROOT="$TMP_DIR/agent" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "Specify only one of prompt_file or prompt_text"
  End

  It "fails when prompt_file and prompt_text are missing"
    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
YAML
    When run bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "prompt_file or prompt_text is required"
  End

  It "renders prompt_file content"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/prompts"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    printf 'from file' > "$AGENT/prompts/sample.md"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_file: prompts/sample.md
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB" --render-only
    The status should be success
    The output should include "from file"
  End

  It "renders prompt with input replacement"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$AGENT/core/oneshot_exec.sh"
    chmod +x "$AGENT/core/oneshot_exec.sh"
    INPUT_PATH="$AGENT/input.txt"
    printf 'world' > "$INPUT_PATH"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: |
  Hello __INPUT_FOO__
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB" --input foo=input.txt --render-only
    The status should be success
    The output should include "run_oneshot_log="
    LOG_PATH="$(ls "$TMP_DIR/test-worklogs/test"/*/logs/run-oneshot.log 2>/dev/null | head -n 1)"
    The path "$LOG_PATH" should exist
    The contents of file "$LOG_PATH" should include "Hello world"
  End

  It "uses ONESHOT_PROJECT_ROOT when target_dir is omitted"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      TARGET="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "target_dir=$TARGET"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    TARGET="$TMP_DIR/target-a"
    mkdir -p "$TARGET"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" ONESHOT_PROJECT_ROOT="$TARGET" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$TARGET"
  End

  It "uses PROJECT_ROOT when ONESHOT_PROJECT_ROOT is empty"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      TARGET="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "target_dir=$TARGET"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    TARGET="$TMP_DIR/target-b"
    mkdir -p "$TARGET"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" ONESHOT_PROJECT_ROOT="" PROJECT_ROOT="$TARGET" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$TARGET"
  End

  It "uses PWD when no target roots are set"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      TARGET="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "target_dir=$TARGET"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    PWD_ROOT="$TMP_DIR/pwd-root"
    mkdir -p "$PWD_ROOT"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash -c "cd '$PWD_ROOT' && bash '$REPO_ROOT/core/run_oneshot.sh' --job '$JOB'"
    The status should be success
    The output should include "target_dir=$PWD_ROOT"
  End

  It "uses explicit target_dir over environment defaults"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C)
      TARGET="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "target_dir=$TARGET"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    TARGET="$TMP_DIR/explicit-target"
    mkdir -p "$TARGET"
    DEFAULT_TARGET="$TMP_DIR/default-target"
    mkdir -p "$DEFAULT_TARGET"

    JOB="$TMP_DIR/job.yml"
    cat <<YAML > "$JOB"
name: test
prompt_text: "hello"
worktree: false
target_dir: "$TARGET"
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" ONESHOT_PROJECT_ROOT="$DEFAULT_TARGET" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$TARGET"
  End

  It "passes skill names to oneshot_exec"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

SKILLS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s)
      SKILLS="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "skills=$SKILLS"
RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
skills:
  - alpha
  - beta
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "skills=alpha,beta"
  End

  It "expands skill files at the head of the prompt"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/skills/optional"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    printf 'skill-file-content' > "$AGENT/skills/optional/sample.md"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "prompt body"
skills:
  - skills/optional/sample.md
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB" --render-only
    The status should be success
    The output should include "# Job Skill Files"
    The output should include "skill-file-content"
    The output should include "prompt body"
  End

  It "passes disable_global_skills to oneshot_exec"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

echo "disable_global=${ONESHOT_DISABLE_GLOBAL_SKILLS:-}"
RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
disable_global_skills: true
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "disable_global=1"
  End

  It "defaults worktree to true and calls create_worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
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

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "create_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "create_worktree_called=1"
  End

  It "fails when job_type and legacy keys are mixed"
    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: worktree
worktree: true
YAML
    When run bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "job_type cannot be used with"
  End

  It "fails when job_type is unknown"
    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: unknown
YAML
    When run bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "Unknown job_type: unknown"
  End

  It "sets no_worktree job_type without calling create_worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: no_worktree
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
  End

  It "sets worktree job_type and calls create_worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
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

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "create_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: worktree
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "create_worktree_called=1"
  End

  It "sets worktree_and_pr job_type and calls create_pr"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
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

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "create_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/generate_pr_yml.sh"
#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="$1"
mkdir -p "$RUN_DIR"
cat <<'YAML' > "$RUN_DIR/pr.yml"
title: test
body: test
YAML

echo "generated: $RUN_DIR/pr.yml"
MOCK
    chmod +x "$AGENT/core/generate_pr_yml.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "create_pr_called=1"
MOCK
    chmod +x "$AGENT/core/create_pr.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: worktree_and_pr
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "create_worktree_called=1"
    The output should include "create_pr_called=1"
  End

  It "supports legacy worktree flag without job_type"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
  End

  It "uses legacy worktree_pr with worktree_pr_input"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/inputs"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail

WORKTREE_ROOT=""
RUN_ID=""
PR_REF=""
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
    --pr)
      PR_REF="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

if [[ -z "$WORKTREE_ROOT" || -z "$RUN_ID" || -z "$PR_REF" ]]; then
  exit 1
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "create_pr_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_pr_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/push_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "push_worktree_called=1"
MOCK
    chmod +x "$AGENT/core/push_worktree.sh"

    printf '123' > "$AGENT/inputs/pr.txt"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree_pr: true
worktree_pr_input: pr
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB" --input pr=inputs/pr.txt
    The status should be success
    The output should include "create_pr_worktree_called=1"
    The output should include "push_worktree_called=1"
  End

  It "maps job_type pr_worktree to PR worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/inputs"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail

WORKTREE_ROOT=""
RUN_ID=""
PR_REF=""
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
    --pr)
      PR_REF="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

if [[ -z "$WORKTREE_ROOT" || -z "$RUN_ID" || -z "$PR_REF" ]]; then
  exit 1
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "create_pr_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_pr_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/push_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "push_worktree_called=1"
MOCK
    chmod +x "$AGENT/core/push_worktree.sh"

    printf '123' > "$AGENT/inputs/pr.txt"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: pr_worktree
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB" --input pr=inputs/pr.txt
    The status should be success
    The output should include "create_pr_worktree_called=1"
    The output should include "push_worktree_called=1"
  End

  It "runs worktree and pr_yml flow"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/worklogs"

    # mock oneshot_exec.sh
    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    # mock create_worktree.sh
    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
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
    chmod +x "$AGENT/core/create_worktree.sh"

    # mock generate_pr_yml.sh
    cat <<'MOCK' > "$AGENT/core/generate_pr_yml.sh"
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
    chmod +x "$AGENT/core/generate_pr_yml.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: true
pr_yml: true
target_dir: /tmp/target
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "worktree_dir="
    The output should include "generated:"
  End

  It "fails when pr_yml is true without worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
pr_yml: true
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "pr_yml requires worktree: true"
  End

  It "passes --draft to create_pr when pr_draft is true"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
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

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"

echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/generate_pr_yml.sh"
#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="$1"
mkdir -p "$RUN_DIR"
cat <<'YAML' > "$RUN_DIR/pr.yml"
title: test
body: test
YAML

echo "generated: $RUN_DIR/pr.yml"
MOCK
    chmod +x "$AGENT/core/generate_pr_yml.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr.sh"
#!/usr/bin/env bash
set -euo pipefail

HAS_DRAFT=0
for arg in "$@"; do
  if [[ "$arg" == "--draft" ]]; then
    HAS_DRAFT=1
    break
  fi
done

if [[ $HAS_DRAFT -eq 1 ]]; then
  echo "draft=1"
  exit 0
fi

echo "draft=0"
exit 1
MOCK
    chmod +x "$AGENT/core/create_pr.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: true
pr: true
pr_draft: true
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "draft=1"
  End

  It "calls create_issue when issue is true"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR/inputs" "$RUN_DIR/logs" "$RUN_DIR/prompts"
cat <<'YAML' > "$RUN_DIR/issue.yml"
title: issue
body: body
YAML

echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_issue.sh"
#!/usr/bin/env bash
set -euo pipefail
echo "create_issue_called=1"
MOCK
    chmod +x "$AGENT/core/create_issue.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
issue: true
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "create_issue_called=1"
  End

  It "passes model and thinking to oneshot_exec"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

echo "model=$ONESHOT_MODEL"
echo "thinking=$ONESHOT_THINKING"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
model: gpt-5.2-codex
thinking: high
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "model=gpt-5.2-codex"
    The output should include "thinking=high"
  End
End
