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
    When run env ONESHOT_AGENT_ROOT="$TMP_DIR/agent" bash core/run_oneshot.sh --job "$JOB"
    The status should be failure
    The stderr should include "prompt_file or prompt_text is required"
  End

  It "uses job file name when name is missing"
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

    JOB="$TMP_DIR/sample-job.yml"
    cat <<'YAML' > "$JOB"
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "run_dir=$TMP_DIR/test-worklogs/sample-job/"
  End

  It "reads prompt_file content"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/prompts"
    printf 'PROMPT_FROM_FILE' > "$AGENT/prompts/test.md"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

PROMPT_PATH="${@: -1}"
cat "$PROMPT_PATH"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_file: prompts/test.md
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "PROMPT_FROM_FILE"
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

  It "selects target_dir from ONESHOT_PROJECT_ROOT first"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    PROJECT_A="$TMP_DIR/project-a"
    PROJECT_B="$TMP_DIR/project-b"

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
    -s)
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "target_dir=$TARGET"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_PROJECT_ROOT="$PROJECT_A" PROJECT_ROOT="$PROJECT_B" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$PROJECT_A"
  End

  It "falls back to PROJECT_ROOT when ONESHOT_PROJECT_ROOT is missing"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    PROJECT_B="$TMP_DIR/project-b"

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
    -s)
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "target_dir=$TARGET"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" PROJECT_ROOT="$PROJECT_B" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$PROJECT_B"
  End

  It "uses current directory when target_dir envs are missing"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    EXPECTED_PWD="$(pwd)"

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
    -s)
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "target_dir=$TARGET"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$EXPECTED_PWD"
  End

  It "uses explicit target_dir when provided"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"
    EXPLICIT_TARGET="$TMP_DIR/explicit-target"

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
    -s)
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "target_dir=$TARGET"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<YAML > "$JOB"
name: test
prompt_text: "hello"
target_dir: $EXPLICIT_TARGET
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_PROJECT_ROOT="$TMP_DIR/project-a" PROJECT_ROOT="$TMP_DIR/project-b" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "target_dir=$EXPLICIT_TARGET"
  End

  It "passes skill names to oneshot_exec via -s"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

SKILLS_VALUE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s)
      SKILLS_VALUE="$2"
      shift 2
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "skills_arg=$SKILLS_VALUE"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
skills:
  - doc-audit
  - other-skill
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "skills_arg=doc-audit,other-skill"
  End

  It "expands skill files at the top of the prompt with --render-only"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/skills/optional"
    printf 'SKILL_FILE_CONTENT' > "$AGENT/skills/optional/custom.md"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "PROMPT_BODY"
skills:
  - skills/optional/custom.md
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB" --render-only
    The status should be success
    The output should include "# Job Skill Files"
    The output should include "## skill_file: skills/optional/custom.md"
    The output should include "SKILL_FILE_CONTENT"
    The output should include "PROMPT_BODY"
  End

  It "passes disable_global_skills as environment variable"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

echo "disable_global=${ONESHOT_DISABLE_GLOBAL_SKILLS:-}"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
disable_global_skills: true
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "disable_global=1"
  End

  It "creates worktree by default"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

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
  WORKTREE_ROOT="${TMP_DIR:-$PWD/worklogs}"
fi
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="run"
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"
echo "create_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "create_worktree_called=1"
  End

  It "does not create worktree when worktree is false"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree: false
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
  End

  It "creates PR worktree with legacy worktree_pr settings"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/inputs"
    printf 'PR-123' > "$AGENT/inputs/pr.txt"

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

if [[ "$PR_REF" != "PR-123" ]]; then
  exit 1
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"
echo "create_pr_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_pr_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
worktree_pr: true
worktree_pr_input: pr
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" bash core/run_oneshot.sh --job "$JOB" --input pr=inputs/pr.txt
    The status should be success
    The output should include "create_pr_worktree_called=1"
  End

  It "fails when pr_yml is true and worktree is false"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

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
mkdir -p "$RUN_DIR"

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

if [[ -z "$WORKTREE_ROOT" ]]; then
  WORKTREE_ROOT="${TMP_DIR:-$PWD/worklogs}"
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

    cat <<'MOCK' > "$AGENT/core/generate_pr_yml.sh"
#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="$1"
mkdir -p "$RUN_DIR"
cat <<'YAML' > "$RUN_DIR/pr.yml"
title: draft
body: test
YAML
MOCK
    chmod +x "$AGENT/core/generate_pr_yml.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr.sh"
#!/usr/bin/env bash
set -euo pipefail

DRAFT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)
      DRAFT=1
      shift 1
      ;;
    *)
      shift 1
      ;;
  esac
done

echo "draft=$DRAFT"
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

  It "creates issue when issue is true"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"

cat <<'YAML' > "$RUN_DIR/issue.yml"
title: test issue
body: test
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

  It "handles job_type no_worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"
echo "run_dir=$RUN_DIR"
MOCK
    chmod +x "$AGENT/core/oneshot_exec.sh"

    cat <<'MOCK' > "$AGENT/core/create_worktree.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_pr.sh"

    JOB="$TMP_DIR/job.yml"
    cat <<'YAML' > "$JOB"
name: test
prompt_text: "hello"
job_type: no_worktree
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
  End

  It "handles job_type worktree"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail
RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"
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

if [[ -z "$WORKTREE_ROOT" ]]; then
  WORKTREE_ROOT="${TMP_DIR:-$PWD/worklogs}"
fi
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="run"
fi

WORKTREE_DIR="$WORKTREE_ROOT/$RUN_ID/worktree"
mkdir -p "$WORKTREE_DIR"
echo "create_worktree_called=1"
echo "worktree_dir=$WORKTREE_DIR"
MOCK
    chmod +x "$AGENT/core/create_worktree.sh"

    cat <<'MOCK' > "$AGENT/core/create_pr.sh"
#!/usr/bin/env bash
set -euo pipefail
exit 1
MOCK
    chmod +x "$AGENT/core/create_pr.sh"

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

  It "handles job_type worktree_and_pr"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core"

    cat <<'MOCK' > "$AGENT/core/oneshot_exec.sh"
#!/usr/bin/env bash
set -euo pipefail

RUNS_DIR="${ONESHOT_RUNS_DIR:-$PWD/worklogs}"
RUN_ID="${ONESHOT_RUN_ID:-run}"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"
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

if [[ -z "$WORKTREE_ROOT" ]]; then
  WORKTREE_ROOT="${TMP_DIR:-$PWD/worklogs}"
fi
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="run"
fi

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

  It "fails on unknown job_type"
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
  End

  It "runs worktree and pr_yml flow"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/core" "$AGENT/worklogs"
    TARGET_DIR="$TMP_DIR/target"

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
    cat <<YAML > "$JOB"
name: test
prompt_text: "hello"
worktree: true
pr_yml: true
target_dir: $TARGET_DIR
YAML

    When run env ONESHOT_AGENT_ROOT="$AGENT" ONESHOT_WORKLOGS_ROOT="$TMP_DIR/test-worklogs" bash core/run_oneshot.sh --job "$JOB"
    The status should be success
    The output should include "worktree_dir="
    The output should include "generated:"
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
