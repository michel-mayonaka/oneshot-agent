# Issue Template Skill

目的:
- issue.yml のフォーマットを統一し、Issue 作成時の抜け漏れを防ぐ。

必須フォーマット:
- title（必須）
- body（必須）
  - 本文に「背景 / 目的 / 作業範囲 / 受け入れ条件 / 参考」を必ず含める。
  - 見出しは `##` を使う。
- labels / assignees / milestone（必要な場合のみ）

複数 Issue の場合:
- 分割理由と各 Issue の要約を本文に含める。
- 出力先は `issues/issue-001.yml` 以降にする。

書き方の注意:
- `core/create_issue.sh` の簡易 YAML パーサに合わせ、複雑な YAML は避ける。
- 配列は以下のいずれかで記述する。
  - 1行ずつ `-` で列挙
  - 1行のカンマ区切り（必要な場合のみ）
- 既存Issueを参照する場合は `issue_url` または `issue_number` を付ける（PRの closing keyword に使用）。

issue.yml 例:
```
title: ○○の説明を最新手順に更新する
body: |
  ## 背景
  ○○の説明が古い

  ## 目的
  最新手順へ更新する

  ## 作業範囲
  - docs/core/04-workflow.md

  ## 受け入れ条件
  - 手順とコマンドが一致する

  ## 参考
  - worklogs/.../report.md
labels:
  - docs
assignees:
  - tkg-engineer
milestone: v1.0
issue_url: "https://github.com/owner/repo/issues/123"
```
