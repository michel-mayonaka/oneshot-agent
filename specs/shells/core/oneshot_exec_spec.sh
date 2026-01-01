#!/usr/bin/env bash
# shellspec

Include specs/shells/spec_helper.sh

Describe "core/oneshot_exec.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when prompt missing"
    When run bash core/oneshot_exec.sh
    The status should be failure
    The output should include "Usage:"
  End

  It "fails when ONESHOT_AGENT_ROOT missing"
    When run env -u ONESHOT_AGENT_ROOT bash core/oneshot_exec.sh "hi"
    The status should be failure
    The stderr should include "ONESHOT_AGENT_ROOT is not set"
  End

  It "writes outputs with optional skills"
    AGENT="$TMP_DIR/agent"
    mkdir -p "$AGENT/skills/global" "$AGENT/skills/optional"
    printf 'global' > "$AGENT/skills/global/g.md"
    printf 'optional' > "$AGENT/skills/optional/foo.md"

    RUNS="$TMP_DIR/runs"

    When run env \
      ONESHOT_AGENT_ROOT="$AGENT" \
      ONESHOT_RUNS_DIR="$RUNS" \
      ONESHOT_RUN_ID="run-1" \
      ONESHOT_AUTO_TRANSLATE_WORKLOG="" \
      bash core/oneshot_exec.sh -s foo "hello"

    The status should be success
    The output should include "run_dir=$RUNS/run-1"
    The output should include "target_dir=$RUNS/run-1/artifacts"
    The path "$RUNS/run-1/prompts/prompt.txt" should exist
    The path "$RUNS/run-1/prompts/skills_used.txt" should exist
    The contents of file "$RUNS/run-1/prompts/skills_used.txt" should include "skills/global/g.md"
    The contents of file "$RUNS/run-1/prompts/skills_used.txt" should include "skills/optional/foo.md"
    The path "$RUNS/run-1/logs/events.jsonl" should exist
    The path "$RUNS/run-1/logs/worklog.md" should exist
  End
End
