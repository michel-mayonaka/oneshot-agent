# Repository Guidelines

このドキュメントは、「ワンショットでコーディングエージェントに仕事をさせるハーネス」として、このリポジトリに貢献する人向けのガイドラインです。

## プロジェクト構成
- ルート:
  - `AGENTS.md`, `README.md`, `Makefile`
  - `core/`: 実行・集計用シェルスクリプト
  - `run-defs/jobs/`: run-oneshot 用の YAML 定義
  - `run-defs/modes/`: Codex 起動時に読ませる情報のバンドル定義（予定）
  - `skills/global/`: すべての run に自動で含めたい共通ガイド
  - `skills/optional/`: 実行時に明示指定して読み込むスキル群
- `core/`:
  - `oneshot-exec.sh`: 単一プロンプトを Codex CLI に投げる実行スクリプト
  - `run-oneshot.sh`: job spec を読み取り、inputs/skills/worktree/PR を束ねて実行
  - `summarize_run.sh`: 実行結果 (`events.jsonl` など) からサマリーレポートを生成
  - `create-worktree.sh` / `remove-worktree.sh`: git worktree の作成・削除
  - `create-pr.sh`: report.md などから PR を作成（GitHub CLI 必須）
  - `translate-worklog-to-ja.sh`: worklog.md を日本語に翻訳
- `worklogs/`: 各 run ごとのログ・プロンプト・レポートを保存（基本は自動生成。手動編集しない）

## 実行・開発コマンド
- `bash core/oneshot-exec.sh "<prompt or path>"`  
  文字列またはプロンプトファイルパスを渡して 1 回分のエージェント実行を行い、`worklogs/<job>/<run_id>/artifacts/` に生成物を作りつつ、`worklogs/` にログを保存します。
- `bash core/oneshot-exec.sh -C /path/to/project "<prompt or path>"`  
  既存プロジェクトディレクトリをカレントディレクトリとして Codex を実行します（ログは引き続きハーネス側の `worklogs/` に保存）。
- `bash core/summarize_run.sh worklogs/<run_id>` / `bash core/summarize_run.sh worklogs/<job>/<run_id>`  
  指定 run の要約レポート (`report.md`) を生成・更新します。
- `bash core/run-oneshot.sh --job run-defs/jobs/doc-audit.yml`  
  job spec に基づく実行（skills / inputs / worktree / PR の一括処理）。
- Codex CLI 前提のため、`codex` コマンドが `PATH` にあることを確認してください。

## コーディングスタイル & 命名
- スクリプトは `bash` + `set -euo pipefail` 前提で記述します。
- 関数名・変数名は読みやすいスネークケースを使用し、日本語コメントは簡潔に。
- 新しいスクリプトやツールはルートに小文字ケバブケース（例: `collect-metrics.sh`）で追加してください。
- リポジトリ内のパス解決は `ONESHOT_AGENT_ROOT` を基準に行い、`../` 参照は使わない（実装時は必須）。

## テスト・検証方針
- 変更後は最低でも以下を手動実行して確認してください:
- `bash core/run-oneshot.sh --job run-defs/jobs/doc-audit.yml`
  - 生成された `worklogs/<job>/<run_id>/report.md` を開き、想定どおりの情報が出力されているか確認
- 既存の引数インターフェース（位置引数 / 必須オプション）を壊さないよう注意してください。

## コミット・PR ガイドライン
- コミットメッセージは日本語の会話形式を推奨（例: `runの要約を改善しました`, `新しいハーネスオプションを追加しました`）。
- PR では:
  - 目的と背景（どんなワークフローを楽にしたいか）
  - 変更内容の要約
  - 確認に使ったコマンド例
  を短く書いてください。
- `worklogs/` の生成物は基本的にコミット対象から除外し、スクリプトやプロンプトの変更に集中してください。

## Skills 設計方針
- エージェント用スキルは Markdown として `skills/` 配下に管理します。
- ディレクトリ:
  - `skills/global/`: すべての run に自動で含めたい共通ガイド（例: セーフティ指針、リファクタリング方針）。
  - `skills/optional/`: タスクごとに `-s` オプションや `ONESHOT_SKILLS` で明示的に指定して読み込むスキル群。
- 実行時のバンドル:
  - `oneshot-exec.sh` は `prompt.raw.txt`（元のプロンプト）と `prompt.txt`（skills を前置した最終プロンプト）を分けて保存します。
  - 使用されたスキルのファイル一覧を `skills_used.txt` に残し、`report.md` のメタデータにも `skills:` として表示します。
  - グローバルスキルを無効化したい場合は `ONESHOT_DISABLE_GLOBAL_SKILLS=1` を設定してください。

## プロンプトサイズ & バリデーション方針（構想段階）
- Skills を盛り込みすぎると精度が落ちる可能性があるため、「検知 → 必要なら制御する」という方針をとります。
- `oneshot-exec.sh` 側での想定:
  - `prompt.txt` 生成後に、文字数・行数・概算トークン数を計測し、`prompt_stats.txt` に保存する。
  - 閾値を越えたら stderr に警告を出す（例: `WARN: prompt is very large; consider trimming skills.`）。
- 環境変数による制御案:
  - `ONESHOT_MAX_PROMPT_CHARS` / `ONESHOT_MAX_PROMPT_TOKENS`: ソフトリミット（警告用）。
  - `ONESHOT_STRICT_PROMPT_LIMIT=1`: 有効な場合は、リミット超過時に実行を中断し、`report.md` に中断理由を書き出す。
- 実装を進める場合は、まず「計測とログ出し」から入り、その後で中断ロジックや skills 側の要約戦略に広げてください。
