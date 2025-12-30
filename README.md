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
- `prompt.txt`: 実際にエージェントへ渡したプロンプト
- `events.jsonl`: Codex CLI のイベントストリーム
- `worklog.txt`: 最終メッセージのテキストログ
- `stderr_and_time.txt`: 実行時間とエラー出力

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

## ディレクトリ構成
- ルート: `AGENTS.md`, `README.md`, `shells/`, `samples/`, `playground/`
- `shells/`: 実行スクリプト（`oneshot-exec.sh`, `summarize_run.sh`）
- `samples/prompts/zero-to-one/`: 0→1 用サンプルプロンプト（`sample-game.md` など）
- `samples/prompts/existing-repo/`: 既存リポジトリ用サンプルプロンプト（`sample-refactor.md` など）
- `worklogs/`: 各 run のログ・レポート（自動生成。通常は手動編集しない）
- `playground/`: サンプルプロンプトなどで生成された成果物を置く作業用ディレクトリ（`.gitignore` 対象）

より詳細な貢献ルールや運用方針は `AGENTS.md` を参照してください。
