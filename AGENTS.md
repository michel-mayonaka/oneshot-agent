# Repository Guidelines

このドキュメントは、「ワンショットでコーディングエージェントに仕事をさせるハーネス」として、このリポジトリに貢献する人向けのガイドラインです。

## プロジェクト構成
- ルート:
  - `AGENTS.md`, `README.md`
  - `shells/`: 実行・集計用シェルスクリプト
  - `samples/prompts/zero-to-one/`: 0→1 用サンプルプロンプト
  - `samples/prompts/existing-repo/`: 既存リポジトリ用サンプルプロンプト
  - `playground/`: サンプルプロンプトなどで生成された成果物を置く作業用ディレクトリ（`.gitignore` 対象）
- `shells/`:
  - `oneshot-exec.sh`: 単一プロンプトを Codex CLI に投げる実行スクリプト
  - `summarize_run.sh`: 実行結果 (`events.jsonl` など) からサマリーレポートを生成
- `worklogs/`: 各 run ごとのログ・プロンプト・レポートを保存（基本は自動生成。手動編集しない）

## 実行・開発コマンド
- `bash shells/oneshot-exec.sh "<prompt or path>"`  
  文字列またはプロンプトファイルパス（例: `samples/prompts/zero-to-one/sample-game.md`）を渡して 1 回分のエージェント実行を行い、`playground/<run_id>/` 配下に生成物を作りつつ、`worklogs/` にログを保存します。
- `bash shells/oneshot-exec.sh -C /path/to/project "<prompt or path>"`  
  既存プロジェクトディレクトリをカレントディレクトリとして Codex を実行します（ログは引き続きハーネス側の `worklogs/` に保存）。
- `bash shells/summarize_run.sh worklogs/<run_id>`  
  指定 run の要約レポート (`summary_report.md`) を生成・更新します。
- Codex CLI 前提のため、`codex` コマンドが `PATH` にあることを確認してください。

## コーディングスタイル & 命名
- スクリプトは `bash` + `set -euo pipefail` 前提で記述します。
- 関数名・変数名は読みやすいスネークケースを使用し、日本語コメントは簡潔に。
- 新しいスクリプトやツールはルートに小文字ケバブケース（例: `collect-metrics.sh`）で追加してください。

## テスト・検証方針
- 変更後は最低でも以下を手動実行して確認してください:
  - `bash shells/oneshot-exec.sh samples/prompts/zero-to-one/sample-game.md`
  - 生成された `worklogs/<run_id>/summary_report.md` を開き、想定どおりの情報が出力されているか確認
- 既存の引数インターフェース（位置引数 / 必須オプション）を壊さないよう注意してください。

## コミット・PR ガイドライン
- コミットメッセージは英語の簡潔な命令形を推奨（例: `Improve run summarization`, `Add new harness option`）。
- PR では:
  - 目的と背景（どんなワークフローを楽にしたいか）
  - 変更内容の要約
  - 確認に使ったコマンド例
  を短く書いてください。
- `worklogs/` の生成物は基本的にコミット対象から除外し、スクリプトやプロンプトの変更に集中してください。
