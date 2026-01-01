#!/usr/bin/env bash
# shellspec

Include specs/shells/spec_helper.sh

Describe "core/generate_pr_yml.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when worklog is missing"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR"
    When run bash core/generate_pr_yml.sh "$RUN_DIR"
    The status should be failure
    The stderr should include "worklog.md not found"
  End

  It "fails when worktree is not a git repo"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR/worktree"
    printf 'log' > "$RUN_DIR/worklog.md"

    When run env GIT_MOCK_GIT_DIR_STATUS=1 bash core/generate_pr_yml.sh "$RUN_DIR"
    The status should be failure
    The stderr should include "worktree is not a git repo"
  End

  It "generates pr.yml"
    RUN_DIR="$TMP_DIR/run"
    mkdir -p "$RUN_DIR/worktree"
    printf 'log' > "$RUN_DIR/worklog.md"

    When run env \
      GIT_MOCK_GIT_DIR_STATUS=0 \
      GIT_MOCK_DIFF_NAMESTATUS="M file.txt" \
      GIT_MOCK_DIFF_STAT=" file.txt | 1 +" \
      GIT_MOCK_DIFF_BODY="diff --git" \
      bash core/generate_pr_yml.sh "$RUN_DIR"

    The status should be success
    The output should include "generated:"
    The path "$RUN_DIR/pr.yml" should exist
  End
End
