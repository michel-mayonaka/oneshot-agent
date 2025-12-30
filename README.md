# oneshot-agent

Codex CLI に「ワンショットで仕事を投げる」ための、シンプルなハーネスです。  
単一プロンプトを実行し、そのときのイベントログとサマリーレポートを `worklogs/` に保存します。

## 前提条件
- Codex CLI (`codex` コマンド) がインストール済みで `PATH` に通っていること
- `bash`, `jq`, `git` が利用可能であること（`jq` はサマリ生成で使用、無い場合は一部情報が省略されます）

## 使い方
### 1. 0→1 用（playground モード・デフォルト）
任意のプロンプト文字列、またはプロンプトファイルを渡して実行します。  
生成物はこのリポジトリ直下ではなく、`playground/<run_id>/` 配下に作られます。

```bash
bash shells/oneshot-exec.sh "Create a small CLI tool in Go"
# またはサンプルプロンプトを使う場合
bash shells/oneshot-exec.sh samples/prompts/zero-to-one/sample-game.md
```

各実行は一意な `run_id` を持ち、`worklogs/<run_id>/` に以下のファイルが保存されます:
- `prompt.raw.txt`: ユーザーが指定した元のプロンプト
- `prompt.txt`: skills を前置した最終プロンプト
- `events.jsonl`: Codex CLI のイベントストリーム
- `worklog.md`: reasoning/agent_message をまとめた作業ログ（Markdown）
- `stderr_and_time.txt`: 実行時間とエラー出力
- `skills_used.txt`: この run で読み込んだ skill ファイル一覧

### 2. 既存リポジトリに対して実行する（-C）
既存プロジェクトのディレクトリを `-C` で指定すると、そのディレクトリをカレントディレクトリとして Codex を実行できます。

```bash
bash shells/oneshot-exec.sh -C /path/to/your-project "Refactor this repo to use tool X"
```

`worklogs/` は常にこのハーネス側に生成されるため、ターゲットリポジトリはログで汚れません。

### 3. 実行結果の要約
特定の run に対してサマリーレポートを生成します。

```bash
bash shells/summarize_run.sh worklogs/<run_id>
```

生成される `summary_report.md` には、使用トークン数・経過時間・Git 状態・プロンプト/出力の抜粋などが含まれます。

## 他リポジトリへの組み込み例
おすすめは「oneshot-agent はこのリポジトリで集中管理し、各プロジェクトにはラッパースクリプトだけ置く」運用です。

1. 開発環境側で `ONESHOT_AGENT_ROOT` を設定:

```bash
export ONESHOT_AGENT_ROOT="$HOME/dev/oneshot-agent"  # このリポジトリのパス
```

2. 各プロジェクトに `scripts/oneshot.sh` を作成:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${ONESHOT_AGENT_ROOT:?ONESHOT_AGENT_ROOT is not set}"

"$ONESHOT_AGENT_ROOT/shells/oneshot-exec.sh" -C "$(pwd)" "$@"
```

3. プロジェクト側での使い方:

```bash
# 既存リポジトリに対してエージェントを実行
bash scripts/oneshot.sh "Add logging around DB queries"

# プロジェクト固有のプロンプトファイルを用意して使う場合
bash scripts/oneshot.sh oneshot/prompts/refactor-logging.md
```

## ディレクトリ構成
- ルート: `AGENTS.md`, `README.md`, `shells/`, `samples/`, `skills/`, `playground/`
- `shells/`: 実行スクリプト（`oneshot-exec.sh`, `summarize_run.sh`）
- `samples/prompts/zero-to-one/`: 0→1 用サンプルプロンプト（`sample-game.md` など）
- `samples/prompts/existing-repo/`: 既存リポジトリ用サンプルプロンプト（`sample-refactor.md` など）
- `skills/global/`: すべての run に前置して読み込まれる共通スキル（Markdown）
- `skills/optional/`: `-s` オプションや `ONESHOT_SKILLS` で明示的に指定する追加スキル
- `worklogs/`: 各 run のログ・レポート（自動生成。通常は手動編集しない）
- `playground/`: サンプルプロンプトなどで生成された成果物を置く作業用ディレクトリ（`.gitignore` 対象）

より詳細な貢献ルールや運用方針は `AGENTS.md` を参照してください。

## 将来の拡張（Skills とプロンプト制御）

このハーネスは、将来的に次のような機能拡張を想定しています。

- **Skills（エージェント用スキル）のバンドル**
  - `skills/global/`: すべての run に自動的に読み込む共通ガイド。
  - `skills/optional/`: 実行時オプション（例: `-s foo,bar`）や環境変数で明示的に指定するスキル。
  - 実行時には、これらの Markdown をユーザープロンプトの前に連結した上で `prompt.txt` を生成し、`skills_used.txt` に使用スキルを記録する方針です。

- **プロンプトサイズの計測とバリデーション**
  - `prompt.txt` の文字数・概算トークン数を計測して `prompt_stats.txt` に保存し、`summary_report.md` にもサイズ情報を載せる構想です。
  - 閾値は環境変数（例: `ONESHOT_MAX_PROMPT_CHARS`, `ONESHOT_MAX_PROMPT_TOKENS`）で調整し、大きすぎる場合は警告、厳格モード（`ONESHOT_STRICT_PROMPT_LIMIT=1`）では実行中断も検討しています。

実装を進める際は、まずこの README と `AGENTS.md` に記載した設計方針に沿って進めてください。
