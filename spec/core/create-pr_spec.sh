#!/usr/bin/env bash
# shellspec

Include spec/spec_helper.sh

Describe "core/create-pr.sh"
  BeforeEach setup_tmp
  AfterEach cleanup_tmp

  It "fails when required args are missing"
    When run bash core/create-pr.sh
    The status should be failure
    The output should include "Usage: create-pr.sh"
  End

  It "fails when gh is missing"
    REPO="$TMP_DIR/repo"
    WORKTREE="$TMP_DIR/worktree"
    mkdir -p "$REPO" "$WORKTREE"
    PR_YML="$TMP_DIR/pr.yml"
    cat <<'YAML' > "$PR_YML"
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

    BIN="$TMP_DIR/bin"
    mkdir -p "$BIN"
    ln -s "$SPEC_ROOT/support/bin/git" "$BIN/git"

    When run env PATH="$BIN:/usr/bin:/bin" bash core/create-pr.sh --repo "$REPO" --worktree "$WORKTREE" --pr-yml "$PR_YML"
    The status should be failure
    The stderr should include "gh command not found"
  End

  It "creates PR with mocks"
    REPO="$TMP_DIR/repo"
    WORKTREE="$TMP_DIR/worktree"
    mkdir -p "$REPO" "$WORKTREE"
    PR_YML="$TMP_DIR/pr.yml"
    cat <<'YAML' > "$PR_YML"
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

    When run env \
      GIT_MOCK_STATUS=" M file.txt" \
      GIT_MOCK_REVLIST_COUNT=1 \
      bash core/create-pr.sh --repo "$REPO" --worktree "$WORKTREE" --pr-yml "$PR_YML"

    The status should be success
    The output should include "pr_url="
  End
End
