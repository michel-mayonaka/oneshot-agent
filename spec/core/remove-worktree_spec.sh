#!/usr/bin/env bash
# shellspec

Include spec/spec_helper.sh

Describe "core/remove-worktree.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when required args are missing"
    When run bash core/remove-worktree.sh
    The status should be failure
    The output should include "Usage: remove-worktree.sh"
  End

  It "fails when repo is not git"
    When run env GIT_MOCK_GIT_DIR_STATUS=1 bash core/remove-worktree.sh --repo /tmp/repo --run-id 1
    The status should be failure
    The stderr should include "Not a git repo"
  End

  It "removes worktree by run-id"
    REPO="$TMP_DIR/repo"
    WORKLOGS_ROOT="$REPO/worklogs"
    WORKTREE_DIR="$WORKLOGS_ROOT/123/worktree"
    mkdir -p "$WORKTREE_DIR"

    When run env GIT_MOCK_GIT_DIR_STATUS=0 bash core/remove-worktree.sh --repo "$REPO" --run-id 123 --worktree-root "$WORKLOGS_ROOT"
    The status should be success
    The output should include "removed_worktree="
    The path "$WORKTREE_DIR" should not exist
  End

  It "removes worktree with --force"
    REPO="$TMP_DIR/repo"
    WORKTREE_DIR="$TMP_DIR/worktree"
    mkdir -p "$WORKTREE_DIR"

    When run env GIT_MOCK_GIT_DIR_STATUS=0 bash core/remove-worktree.sh --repo "$REPO" --path "$WORKTREE_DIR" --force
    The status should be success
    The output should include "removed_worktree="
  End
End
