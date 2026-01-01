# oneshot-exec.sh リファレンス

## 概要
- 単一プロンプトを Codex CLI で実行し、ログと成果物を `worklogs/` に保存します。
- プロンプトは「グローバル/オプショナルの skill」を前置した最終版を生成します。

根拠: `core/oneshot-exec.sh`

## CLI
```
Usage: oneshot-exec.sh [-C <target_dir>] [-s skill1,skill2] <prompt.txt or prompt string>

  -C DIR   Codex を実行するターゲットディレクトリ（既存リポジトリなど）
  -s NAME  optional skill 名（カンマ区切り、skills/optional/<NAME>.md を参照）
```

根拠: `core/oneshot-exec.sh`

## 環境変数
- `ONESHOT_AGENT_ROOT`（必須）: リポジトリルート。
- `ONESHOT_RUN_ID`（任意）: run_id を指定。未指定なら `date +%Y%m%d-%H%M%S` と `$RANDOM` で生成。
- `ONESHOT_RUNS_DIR`（任意）: run 出力のルート。未指定時は `<ONESHOT_AGENT_ROOT>/worklogs/oneshot-exec`。
- `ONESHOT_SKILLS`（任意）: optional skill 名（カンマ区切り）。
- `ONESHOT_DISABLE_GLOBAL_SKILLS`（任意）: `1` で global skills を無効化。
- `ONESHOT_MODEL`（任意）: Codex 実行モデル（未指定時は `gpt-5.2-codex`）。
- `ONESHOT_THINKING`（任意）: `reasoning.effort` に渡す値。
- `ONESHOT_ARCHIVE_HANDLED`（任意）: 未設定時のみ旧 run のアーカイブ処理を行う。
- `ONESHOT_AUTO_TRANSLATE_WORKLOG`（任意）: 設定時に `translate-worklog-to-ja.sh` を実行。

根拠: `core/oneshot-exec.sh`

## 入力
- 第1引数にプロンプト文字列、またはプロンプトファイルパスを指定。
- プロンプトは `prompts/prompt.raw.txt` に保存され、skills を前置した最終版を `prompts/prompt.txt` に出力。

根拠: `core/oneshot-exec.sh`

## 出力/生成物
- run ディレクトリ配下に以下を作成。
  - `logs/events.jsonl`
  - `logs/stderr_and_time.txt`
  - `logs/worklog.md`
  - `logs/commands.jsonl`
  - `logs/worklog.commands.md`
  - `logs/last_message.md`
  - `logs/usage.json`
  - `logs/target_dir.txt`
  - `prompts/prompt.raw.txt`
  - `prompts/prompt.txt`
  - `prompts/skills_used.txt`
  - `report.md`（`summarize_run.sh` により生成）
- 標準出力に `run_dir=<...>` と `target_dir=<...>` を出力。

根拠: `core/oneshot-exec.sh`

## 主な処理フロー
1. run_id と run ディレクトリを確定し、`.running` を作成。
2. 旧 run を `archive/` に退避（`ONESHOT_ARCHIVE_HANDLED` 未設定時）。
3. ターゲットディレクトリ決定（`-C` が無い場合は `<run_dir>/artifacts`）。
4. skills を解決し、最終プロンプトを生成。
5. `codex exec` を実行し、`events.jsonl` を保存。
6. `jq` でログ/usage を抽出して各種ファイルを生成。
7. `summarize_run.sh` を実行。
8. `ONESHOT_AUTO_TRANSLATE_WORKLOG` が設定されていれば翻訳を実行。

根拠: `core/oneshot-exec.sh`

## 注意点
- `codex` CLI を直接呼び出します（存在チェックはありません）。
- `jq` を使用してログ整形を行います（存在チェックはありません）。
- `/usr/bin/time -p` を使用して時間計測を行います。

根拠: `core/oneshot-exec.sh`
