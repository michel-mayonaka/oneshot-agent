---
name: pr-draft
description: Generate PR title and body from the performed changes and include them in the report under a fixed heading.
---

# PR情報の作成

変更内容に基づいて、PRに使えるタイトルと本文を作成してください。
レポート内に **必ず** 次の形式で出力します。

## PR情報

タイトル: <1行で簡潔なPRタイトル>
本文:
<本文を複数行で記載。概要/変更点/確認コマンドを含める>

注意:
- 見出し名は必ず「PR情報」。
- タイトル行は必ず「タイトル:」で始める。
- 本文は「本文:」の次の行から書く。
- 本文にURLが必要なら、文章内に直接書かずプレーンテキストで記載する。
