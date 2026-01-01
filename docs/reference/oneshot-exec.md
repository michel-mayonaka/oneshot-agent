# oneshot-exec.sh 参照

## 概要
`core/oneshot-exec.sh` は、単一プロンプトで Codex CLI を実行し、run ディレクトリとログを生成します。

## CLI
```
Usage: oneshot-exec.sh [-C <target_dir>] [-s skill1,skill2] <prompt.txt or prompt string>

  -C DIR   Codex を実行するターゲットディレクトリ（既存リポジトリなど）。
           省略時は、worklogs/<run_id>/artifacts/ を作成して使用します。
  -s NAME  追加で読み込む optional skill 名（カンマ区切り可）。skills/optional/<NAME>.md を参照します。
```

## 必須環境変数
- `ONESHOT_AGENT_ROOT`: リポジトリのルートパス。未設定の場合は即時エラー。

## 任意の環境変数
- `ONESHOT_SKILLS`: 追加の optional skill 名（カンマ区切り）。
- `ONESHOT_DISABLE_GLOBAL_SKILLS`: `1` の場合、`skills/global/` を読み込まない。
- `ONESHOT_MODEL`: Codex 実行モデル（未指定時 `gpt-5.2-codex`）。
- `ONESHOT_THINKING`: `reasoning.effort` に渡すレベル（例: `low/medium/high`）。
- `ONESHOT_RUN_ID`: run_id を外部から指定。
- `ONESHOT_RUNS_DIR`: run ルート（既定は `<ONESHOT_AGENT_ROOT>/worklogs/oneshot-exec`）。
- `ONESHOT_ARCHIVE_HANDLED`: 既存 run のアーカイブ処理を抑止。
- `ONESHOT_AUTO_TRANSLATE_WORKLOG`: 設定時に `translate-worklog-to-ja.sh` を呼び出す。

## 挙動の要点
- 旧 run は `archive/` に移動（`ONESHOT_ARCHIVE_HANDLED` が未設定の場合）。
- グローバル/オプショナル skill を結合し、`prompts/prompt.txt` を生成。
- Codex は `codex exec --skip-git-repo-check --full-auto --model <MODEL>` で実行。
- 実行後に `summarize_run.sh` を呼び出して `report.md` を生成。

## 主要な出力
- `worklogs/oneshot-exec/<run_id>/` 以下にログ・プロンプト・入力を保存。
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
  - `inputs/`（空のこともある）

## 依存コマンド
- `codex`
- `jq`
- `/usr/bin/time`
- `tee`

## 根拠
- `core/oneshot-exec.sh`
