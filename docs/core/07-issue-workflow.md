# Issue 作成・参照ワークフロー

## 目的
- 調査結果や計画内容から Issue を安定したフォーマットで作成する。
- Issue を参照して作業を実行できるようにする。

## Issue フォーマット（issue.yml）
必須キーは `title` と `body` です。その他は必要な場合のみ指定します。
既存Issueを参照する場合は `issue_url` または `issue_number` を追加します（PRの自動Closeに利用）。

```yaml
title: "短いタイトル"
body: |
  # 背景
  - ...
  # 目的
  - ...
  # 作業範囲
  - ...
  # 受け入れ条件
  - ...
  # 参考
  - ...
labels:
  - bug
  - docs
assignees:
  - username
milestone: "v1.2"
issue_url: "https://github.com/owner/repo/issues/123"
```

### 具体例
```yaml
title: "doc-audit-fix の手順説明を更新する"
body: |
  # 背景
  - README.md と docs の手順が一致していない
  # 目的
  - 実行例を最新のジョブ名に合わせる
  # 作業範囲
  - README.md
  - docs/core/04-workflow.md
  # 受け入れ条件
  - 例に記載のジョブ名が一致している
  # 参考
  - worklogs/.../report.md
labels:
  - docs
assignees:
  - tkg-engineer
milestone: "v1.0"
issue_url: "https://github.com/owner/repo/issues/123"
```

複数 Issue が必要な場合は、`issue.yml` を複数ファイルに分割します。
`run-defs/jobs/issue-create.yml` は `issues/issue-001.yml` のように連番で出力する想定です。

## 作成フロー
1. `run-defs/jobs/issue-create.yml` を実行し、issue.yml を生成します。
2. `core/run_oneshot.sh` が `core/create_issue.sh` を呼び出し、GitHub Issue を作成します。

## 参照フロー
1. `core/fetch_issue.sh` で Issue を `issue.yml` へ取得します。
2. `run-defs/jobs/issue-apply.yml` に `--input issue=...` で渡して実行します。
   - `fetch_issue.sh` で `issue_url` が追加され、PR作成時の closing keyword に使われます。

## 関連スクリプト
- `core/create_issue.sh`: issue.yml から Issue を作成（要 gh）。
- `core/fetch_issue.sh`: Issue を取得して issue.yml を生成（要 gh）。
