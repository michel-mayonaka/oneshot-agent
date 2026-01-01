#!/usr/bin/env bash
# shellspec

Include specs/shells/spec_helper.sh

Describe "core/translate_worklog_to_ja.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when worklog is missing"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR"
    When run bash core/translate_worklog_to_ja.sh "$RUN_DIR"
    The status should be failure
    The stderr should include "worklog.md not found"
  End

  It "fails when codex is missing"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR"
    printf 'log' > "$RUN_DIR/worklog.md"

    BIN="$TMP_DIR/bin"
    mkdir -p "$BIN"

    When run env PATH="$BIN:/usr/bin:/bin" bash core/translate_worklog_to_ja.sh "$RUN_DIR"
    The status should be failure
    The stderr should include "codex CLI not found"
  End

  It "generates translated worklog"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR"
    printf 'log' > "$RUN_DIR/worklog.md"

    When run bash core/translate_worklog_to_ja.sh "$RUN_DIR"
    The status should be success
    The output should include "generated:"
    The path "$RUN_DIR/worklog.ja.md" should exist
  End
End
