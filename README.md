# oneshot-agent

Codex CLI に「ワンショットで仕事を投げる」ための、シンプルなハーネスです。  
単一プロンプトを実行し、そのときのイベントログとサマリーレポートを `worklogs/` に保存します。

## 前提条件
- Codex CLI (`codex` コマンド) がインストール済みで `PATH` に通っていること
- `bash`, `jq`, `git` が利用可能であること（`jq` はサマリ生成で使用、無い場合は一部情報が省略されます）

## 使い方
### 1. ワンショット実行
任意のプロンプト文字列、またはプロンプトファイルを渡して実行します。

```bash
bash oneshot-exec.sh "Create a small CLI tool in Go"
# または
bash oneshot-exec.sh prompt-jp.md
```

各実行は一意な `run_id` を持ち、`worklogs/<run_id>/` に以下のファイルが保存されます:
- `prompt.txt`: 実際にエージェントへ渡したプロンプト
- `events.jsonl`: Codex CLI のイベントストリーム
- `worklog.txt`: 最終メッセージのテキストログ
- `stderr_and_time.txt`: 実行時間とエラー出力

### 2. 実行結果の要約
特定の run に対してサマリーレポートを生成します。

```bash
bash summarize_run.sh worklogs/<run_id>
```

生成される `summary_report.md` には、使用トークン数・経過時間・Git 状態・プロンプト/出力の抜粋などが含まれます。

## ディレクトリ構成
- ルート: `oneshot-exec.sh`, `summarize_run.sh`, `prompt-en.md`, `prompt-jp.md`, `AGENTS.md`
- `worklogs/`: 各 run のログ・レポート（自動生成。通常は手動編集しない）

より詳細な貢献ルールや運用方針は `AGENTS.md` を参照してください。
