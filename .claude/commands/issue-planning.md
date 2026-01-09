# Issue Planning Command

以下の依頼をもとに、作業計画とIssue案を作成し、承認後にIssue化してください。
可能な限り決め切る方針で進め、仮名や暫定案は使わないでください。

## 依頼内容

{{REQUEST}}

## 手順

1. **目的/背景/スコープを整理する**
   - 依頼内容を分析し、何を実現したいのかを明確化
   - 必要に応じてコードベースを調査（関連ファイル、既存実装など）

2. **簡易調査を行う（必要な場合）**
   - 根拠を明記しながら調査
   - 既存のドキュメントやコードを確認

3. **具体的なタスク分解と順序を作る**
   - 実装可能な単位にタスクを分解
   - 依存関係と実装順序を明確化

4. **Issue案を作成する**
   - 複数Issueが妥当なら分割する
   - issue.ymlフォーマットで出力準備

## Issue.ymlフォーマット

以下のフォーマットでIssue内容を作成してください：

```yaml
title: "明確で簡潔なタイトル"
body: |
  ## 背景
  - なぜこの作業が必要か

  ## 目的
  - 何を実現したいか

  ## 作業範囲
  - 変更対象のファイルや機能

  ## 受け入れ条件
  - 完了とみなす基準

  ## 参考
  - 関連情報やドキュメント

labels:
  - enhancement
  - documentation
assignees:
  - username
```

## Issue作成の実行

承認を得たら、以下のコマンドでIssueを作成できます：

```bash
# issue.ymlを作成後
bash core/create_issue.sh --repo "$PWD" --issue-yml issue.yml
```

または、makeコマンド経由：

```bash
# 既存のplanningモードを使用
make mode-planning PLAN_REQUEST=<your-request-file>
```

## 注意事項

- 断定が難しい場合は「要確認」と明記する
- コードベースの調査結果は根拠を示す
- Issue本文は具体的かつ実行可能な内容にする
- 複数Issueが必要な場合は、依存関係を明記する

## 参考スキル

このコマンドは以下のスキルとテンプレートを参照します：
- `skills/optional/issue-template.md`
- `docs/core/07-issue-workflow.md`
