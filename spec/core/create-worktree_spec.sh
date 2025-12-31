#!/usr/bin/env bash
# shellspec

Include spec/spec_helper.sh

Describe "core/create-worktree.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when required args are missing"
    When run bash core/create-worktree.sh
    The status should be failure
    The output should include "Usage: create-worktree.sh"
  End

  It "fails when repo is not git"
    When run env GIT_MOCK_GIT_DIR_STATUS=1 bash core/create-worktree.sh --repo /tmp/repo --run-id 1 --spec-name test
    The status should be failure
    The stderr should include "Not a git repo"
  End

  It "creates worktree"
    REPO="$TMP_DIR/repo"
    mkdir -p "$REPO"

    When run env GIT_MOCK_GIT_DIR_STATUS=0 bash core/create-worktree.sh --repo "$REPO" --run-id 123 --spec-name test
    The status should be success
    The output should include "worktree_dir="
  End

  It "fails when branch exists"
    REPO="$TMP_DIR/repo"
    mkdir -p "$REPO"

    When run env GIT_MOCK_GIT_DIR_STATUS=0 GIT_MOCK_SHOW_REF_EXISTS=1 bash core/create-worktree.sh --repo "$REPO" --run-id 123 --spec-name test
    The status should be failure
    The stderr should include "Branch already exists"
  End

  It "fails when worktree dir already exists"
    REPO="$TMP_DIR/repo"
    WORKLOGS_ROOT="$REPO/worklogs"
    mkdir -p "$WORKLOGS_ROOT/123/worktree"

    When run env GIT_MOCK_GIT_DIR_STATUS=0 bash core/create-worktree.sh --repo "$REPO" --run-id 123 --spec-name test --worktree-root "$WORKLOGS_ROOT"
    The status should be failure
    The stderr should include "Worktree dir already exists"
  End
End
