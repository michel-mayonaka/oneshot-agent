# アーキテクチャ概要

## 全体像（Input -> Process -> Output）
```
[Prompt/Job/Skills/Inputs]
        |
        v
  run_oneshot.sh
        |
  (worktree作成: 任意)
        |
     oneshot_exec.sh
        |
     codex exec
        |
  logs/events.jsonl
        |
   summarize_run.sh
        |
      report.md
```

## 主要コンポーネント
- `core/oneshot_exec.sh`: 単発実行とログ作成。
- `core/run_oneshot.sh`: job spec 解釈と実行統合。
- `core/summarize_run.sh`: レポート生成。
- `core/create_worktree.sh`: worktree 作成。
- `core/remove_worktree.sh`: worktree 削除。
- `core/generate_pr_yml.sh`: PR下書き生成。
- `core/create_pr.sh`: PR作成（要 gh）。
- `core/translate_worklog_to_ja.sh`: ログ翻訳。

## ディレクトリ責務マップ
- `core/`: 実行・集計のスクリプト群。
- `run-defs/jobs/`: run_oneshot 用 YAML 定義。
- `run-defs/modes/`: Codex 起動時に読ませる情報のバンドル定義（予定）。
- `skills/global/`: 常時前置するガイド。
- `skills/optional/`: 任意で読み込むガイド。
- `specs/shells/`: ShellSpec のテスト。
- `tools/`: 補助スクリプト。
- `worklogs/`: 実行ログと成果物。

## データフロー
1. job spec と prompt を解釈します。
2. inputs を置換します。
3. 必要なら worktree を作成します。
4. Codex CLI を実行します。
5. JSONL を元にログを生成します。
6. レポートを生成します。

## 拡張ポイント
- `run-defs/jobs/` に新しい定義を追加します。
- `skills/optional/` にタスク別ガイドを追加します。
- `core/` に補助スクリプトを追加します。
- `specs/shells/` にテストを追加します。

## 保証
- 上記の責務分離を維持します。

## 仮定
- 依存コマンドが動作します。
