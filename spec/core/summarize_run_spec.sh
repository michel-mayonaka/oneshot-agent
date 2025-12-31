#!/usr/bin/env bash
# shellspec

Include spec/spec_helper.sh

Describe "core/summarize_run.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "generates report with jq"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR/logs" "$RUN_DIR/prompts"
    printf '' > "$RUN_DIR/logs/events.jsonl"
    cat <<'TXT' > "$RUN_DIR/logs/stderr_and_time.txt"
real 1.23
user 0.12
sys 0.34
TXT
    printf 'prompt' > "$RUN_DIR/prompts/prompt.txt"
    printf 'message' > "$RUN_DIR/logs/last_message.md"

    When run env GIT_MOCK_INSIDE_WORKTREE=0 bash core/summarize_run.sh "$RUN_DIR"
    The status should be success
    The output should include "generated:"
    The path "$RUN_DIR/report.md" should exist
  End

  It "generates report without jq"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR/logs" "$RUN_DIR/prompts"
    printf '' > "$RUN_DIR/logs/events.jsonl"
    printf 'prompt' > "$RUN_DIR/prompts/prompt.txt"

    BIN="$TMP_DIR/bin"
    mkdir -p "$BIN"
    # Provide git mock only, omit jq
    ln -s "$SPEC_ROOT/support/bin/git" "$BIN/git"

    When run env PATH="$BIN:/usr/bin:/bin" GIT_MOCK_INSIDE_WORKTREE=0 bash core/summarize_run.sh "$RUN_DIR"
    The status should be success
    The output should include "generated:"
    The path "$RUN_DIR/report.md" should exist
  End
End
